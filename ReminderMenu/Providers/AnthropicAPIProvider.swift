import Foundation

/// Anthropic Messages API (`POST https://api.anthropic.com/v1/messages`) を URLSession で直接叩く。
/// 必須ヘッダー: x-api-key, anthropic-version, Content-Type。
struct AnthropicAPIProvider: AIProvider {
    var providerID: AIProviderID { .anthropic }

    let apiKey: String
    let model: String

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    func isReady() -> Bool { !apiKey.isEmpty }

    func runJSON(prompt: String, timeoutSeconds: TimeInterval) async throws -> String {
        guard isReady() else {
            throw AIProviderError.notReady("Anthropic API キーが未設定です。Hutch の設定から登録してください。")
        }

        // Messages API: messages[].role / content
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.generic("Anthropic API: HTTP レスポンスが取得できませんでした")
        }
        if http.statusCode != 200 {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIProviderError.httpError(http.statusCode, bodyText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]] else {
            throw AIProviderError.decodingFailed
        }
        // 最初の text ブロックを返す
        for b in blocks where (b["type"] as? String) == "text" {
            if let text = b["text"] as? String { return text }
        }
        throw AIProviderError.decodingFailed
    }
}
