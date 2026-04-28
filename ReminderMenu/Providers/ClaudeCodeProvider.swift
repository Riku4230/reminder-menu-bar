import Foundation

/// `claude -p` CLI を呼び出すプロバイダ。
/// ユーザーが Claude Code をインストール済み (Max/Team/Enterprise サブスクリプション認証 or ANTHROPIC_API_KEY) であることが前提。
struct ClaudeCodeProvider: AIProvider {
    var providerID: AIProviderID { .claudeCode }

    func isReady() -> Bool {
        // PATH 上に claude が居れば OK とみなす（実行は Process(execute:) 任せ）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "claude"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func runJSON(prompt: String, timeoutSeconds: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["claude", "-p", prompt]

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: AIProviderError.generic("claude 起動失敗: \(error.localizedDescription)"))
                    return
                }

                // タイムアウト監視
                let deadline = DispatchTime.now() + timeoutSeconds
                let group = DispatchGroup()
                group.enter()
                process.terminationHandler = { _ in group.leave() }
                let waitResult = group.wait(timeout: deadline)
                if waitResult == .timedOut {
                    process.terminate()
                    continuation.resume(throwing: AIProviderError.timedOut)
                    return
                }

                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                    continuation.resume(throwing: AIProviderError.generic("claude が空のレスポンスを返しました"))
                    return
                }
                continuation.resume(returning: text)
            }
        }
    }
}
