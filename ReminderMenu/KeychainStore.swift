import Foundation
import Security

/// API キーなどの秘密情報を macOS Keychain に保存する薄いラッパー。
///
/// セキュリティ設計:
/// - `kSecClassGenericPassword` で macOS Keychain の暗号化ストレージに保存。
/// - `kSecAttrService` でアプリ専用のスコープを切る。
/// - `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` でデバイス単位に固定し、
///   バックアップ／iCloud 経由で他デバイスへ転送されないようにする。
/// - `kSecAttrSynchronizable = false` で iCloud Keychain 同期を明示的に無効化。
/// - 値はメモリに長く保持せず、必要な時だけ読み出して即時利用する。
enum KeychainStore {
    private static let service = "dev.remindermenu.app.apikeys"

    /// 取得。見つからない場合は nil。
    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 値が nil または空文字なら削除、それ以外は保存（既存があれば更新）。
    static func set(_ account: String, value: String?) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        guard let value, !value.isEmpty else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }
        guard let data = value.data(using: .utf8) else { return }

        // まず既存があれば更新を試みる
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            // 新規追加
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        } else {
            // 想定外。一旦削除してから再追加する保険ルート。
            SecItemDelete(baseQuery as CFDictionary)
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
