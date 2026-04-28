import Foundation

/// Google Gemini API (`POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`).
/// 認証はクエリパラメータ `?key=` を使用（x-goog-api-key ヘッダーでも可）。
struct GeminiProvider: AIProvider {
    var providerID: AIProviderID { .gemini }

    let apiKey: String
    let model: String

    func isReady() -> Bool { !apiKey.isEmpty }

    func runJSON(prompt: String, timeoutSeconds: TimeInterval) async throws -> String {
        guard isReady() else {
            throw AIProviderError.notReady("Gemini API キーが未設定です。Hutch の設定から登録してください。")
        }
        guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw AIProviderError.generic("Gemini エンドポイント URL の組み立てに失敗")
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components.url else { throw AIProviderError.generic("Gemini URL 解決失敗") }

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.generic("Gemini API: HTTP レスポンスが取得できませんでした")
        }
        if http.statusCode != 200 {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AIProviderError.httpError(http.statusCode, bodyText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIProviderError.decodingFailed
        }
        let text = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        if text.isEmpty { throw AIProviderError.decodingFailed }
        return text
    }
}
