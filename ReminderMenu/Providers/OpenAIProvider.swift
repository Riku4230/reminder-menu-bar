import Foundation

/// OpenAI Responses API (`POST https://api.openai.com/v1/responses`) を URLSession で直接叩く。
/// 旧 Chat Completions ではなく、GPT-5 系で推奨される最新エンドポイントを使用。
struct OpenAIProvider: AIProvider {
    var providerID: AIProviderID { .openai }

    let apiKey: String
    let model: String

    private static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func isReady() -> Bool { !apiKey.isEmpty }

    func runJSON(prompt: String, timeoutSeconds: TimeInterval) async throws -> String {
        guard isReady() else {
            throw AIProviderError.notReady("OpenAI API キーが未設定です。Hutch の設定から登録してください。")
        }

        // Responses API は input にプロンプトをそのまま渡せる
        let body: [String: Any] = [
            "model": model,
            "input": prompt
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.generic("OpenAI API: HTTP レスポンスが取得できませんでした")
        }
        if http.statusCode != 200 {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIProviderError.httpError(http.statusCode, bodyText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.decodingFailed
        }

        // 1) ショートカット: SDK 風の output_text フィールドがあれば使う
        if let direct = json["output_text"] as? String, !direct.isEmpty {
            return direct
        }

        // 2) output[*].content[*].text を集約
        guard let outputArray = json["output"] as? [[String: Any]] else {
            throw AIProviderError.decodingFailed
        }
        var collected: [String] = []
        for item in outputArray where (item["type"] as? String) == "message" {
            guard let contentArr = item["content"] as? [[String: Any]] else { continue }
            for c in contentArr {
                let type = c["type"] as? String
                if type == "output_text" || type == "text",
                   let t = c["text"] as? String {
                    collected.append(t)
                }
            }
        }
        if collected.isEmpty { throw AIProviderError.decodingFailed }
        return collected.joined(separator: "\n")
    }
}
