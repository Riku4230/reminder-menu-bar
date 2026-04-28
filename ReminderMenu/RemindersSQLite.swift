import Foundation
import SQLite3

/// 純正リマインダー.app の SQLite を read-only で開いて親子関係を読む。
///
/// EventKit はサブタスクの親子関係を公開 API で露出していないため、
/// `~/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores/Data-*.sqlite`
/// を直接読んでギャップを埋める。Group Container 配下のため Full Disk Access (FDA) が必要。
enum RemindersSQLite {
    enum AccessError: Error {
        case databaseNotFound
        case permissionDenied   // FDA 未許可と推定
        case openFailed(String)
        case queryFailed(String)
    }

    private static let storesPath =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.reminders/Container_v1/Stores")

    /// 最新の Data-*.sqlite ファイルを返す。複数ある場合は更新日時が最も新しいものを採用。
    static func locateDatabase() -> URL? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: storesPath,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let candidates = files.filter {
            $0.lastPathComponent.hasPrefix("Data-") && $0.pathExtension == "sqlite"
        }

        return candidates.max { lhs, rhs in
            let lm = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rm = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lm < rm
        }
    }

    /// child reminder identifier → parent reminder identifier のマップを返す。
    /// 失敗時は throw。FDA 未許可は `.permissionDenied` に正規化される。
    static func loadParentMap() throws -> [String: String] {
        guard let dbURL = locateDatabase() else {
            // Stores ディレクトリ自体が見えない場合は、TCC で弾かれている可能性が高い
            if !FileManager.default.isReadableFile(atPath: storesPath.path) {
                throw AccessError.permissionDenied
            }
            throw AccessError.databaseNotFound
        }

        // CoreData の WAL/SHM と一緒に一時ディレクトリへコピーしてから開く。
        // 純正アプリが書き込み中でも安定して読めるようにするため。
        let snapshot = try snapshotDatabase(at: dbURL)
        defer { try? FileManager.default.removeItem(at: snapshot.directory) }

        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(
            snapshot.databasePath.path,
            &db,
            SQLITE_OPEN_READONLY,
            nil
        )
        defer { sqlite3_close(db) }

        if openResult != SQLITE_OK {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if openResult == SQLITE_AUTH || openResult == SQLITE_CANTOPEN || openResult == SQLITE_PERM {
                throw AccessError.permissionDenied
            }
            throw AccessError.openFailed("sqlite3_open_v2 failed (\(openResult)): \(message)")
        }

        let columns = try tableColumns(db: db, table: "ZREMCDREMINDER")
        // macOS バージョンでカラム名が揺れる可能性があるためフォールバックを試す
        let parentColumn = ["ZCKPARENTREMINDERIDENTIFIER", "ZPARENTREMINDERIDENTIFIER"]
            .first { columns.contains($0) }
        let identifierColumn = ["ZCKIDENTIFIER", "ZIDENTIFIER", "ZCALENDARITEMUNIQUEIDENTIFIER"]
            .first { columns.contains($0) }

        guard let parentColumn, let identifierColumn else {
            throw AccessError.queryFailed("expected columns not found in ZREMCDREMINDER (have: \(columns.joined(separator: ",")))")
        }

        let deletionFilter = columns.contains("ZMARKEDFORDELETION") ? "AND ZMARKEDFORDELETION = 0" : ""
        let sql = """
            SELECT \(identifierColumn), \(parentColumn)
            FROM ZREMCDREMINDER
            WHERE \(parentColumn) IS NOT NULL
              AND \(parentColumn) != ''
              \(deletionFilter)
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw AccessError.queryFailed("prepare failed: \(message)")
        }
        defer { sqlite3_finalize(statement) }

        var map: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let cChild = sqlite3_column_text(statement, 0),
                let cParent = sqlite3_column_text(statement, 1)
            else { continue }
            let child = String(cString: cChild)
            let parent = String(cString: cParent)
            if !child.isEmpty && !parent.isEmpty {
                map[child] = parent
            }
        }

        return map
    }

    // MARK: - Helpers

    private struct Snapshot {
        let directory: URL
        let databasePath: URL
    }

    private static func snapshotDatabase(at dbURL: URL) throws -> Snapshot {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("ReminderMenu-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let baseName = dbURL.lastPathComponent
        let dest = tempDir.appendingPathComponent(baseName)

        do {
            try fm.copyItem(at: dbURL, to: dest)
        } catch {
            // copyItem 失敗は概ね TCC（オペレーション拒否）。permissionDenied に正規化。
            if (error as NSError).domain == NSPOSIXErrorDomain || (error as NSError).code == NSFileReadNoPermissionError {
                throw AccessError.permissionDenied
            }
            throw AccessError.permissionDenied
        }

        // WAL / SHM もあれば一緒にコピー（無くても問題なし）
        for suffix in ["-wal", "-shm"] {
            let sidecarSrc = URL(fileURLWithPath: dbURL.path + suffix)
            if fm.fileExists(atPath: sidecarSrc.path) {
                let sidecarDest = URL(fileURLWithPath: dest.path + suffix)
                try? fm.copyItem(at: sidecarSrc, to: sidecarDest)
            }
        }

        return Snapshot(directory: tempDir, databasePath: dest)
    }

    private static func tableColumns(db: OpaquePointer?, table: String) throws -> Set<String> {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table))"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw AccessError.queryFailed("PRAGMA failed: \(message)")
        }
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cName = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: cName))
            }
        }
        if names.isEmpty {
            throw AccessError.queryFailed("table \(table) not found")
        }
        return names
    }
}
