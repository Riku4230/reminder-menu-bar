import Foundation

enum AIProviderID: String, CaseIterable, Identifiable, Codable {
    case claudeCode
    case anthropic
    case openai
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .anthropic:  return "Claude API"
        case .openai:     return "OpenAI"
        case .gemini:     return "Gemini"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .claudeCode: return false
        default: return true
        }
    }

    /// Default model id used when the user hasn't chosen one yet.
    var defaultModel: String {
        switch self {
        case .claudeCode: return ""
        case .anthropic:  return "claude-haiku-4-5"
        case .openai:     return "gpt-5-mini"
        case .gemini:     return "gemini-2.5-flash"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claudeCode:
            return []
        case .anthropic:
            return ["claude-haiku-4-5", "claude-sonnet-4-6", "claude-opus-4-7"]
        case .openai:
            // OpenAI Responses API (/v1/responses) で受け付けられる現役モデル
            return ["gpt-5-mini", "gpt-5", "gpt-5.5", "gpt-4.1-mini", "gpt-4.1"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-pro"]
        }
    }

    var apiKeyURL: URL? {
        switch self {
        case .claudeCode: return nil
        case .anthropic:  return URL(string: "https://console.anthropic.com/settings/keys")
        case .openai:     return URL(string: "https://platform.openai.com/api-keys")
        case .gemini:     return URL(string: "https://aistudio.google.com/apikey")
        }
    }
}

protocol AIProvider {
    var providerID: AIProviderID { get }

    /// Auto detect availability (Claude Code: CLI exists; API providers: API key exists).
    func isReady() -> Bool

    /// Run the prompt, return the raw text response (JSON expected by callers).
    func runJSON(prompt: String, timeoutSeconds: TimeInterval) async throws -> String
}

enum AIProviderError: Error, LocalizedError {
    case notReady(String)
    case timedOut
    case httpError(Int, String)
    case decodingFailed
    case generic(String)

    var errorDescription: String? {
        switch self {
        case .notReady(let msg): return msg
        case .timedOut: return "AI 応答がタイムアウトしました"
        case .httpError(let code, let body):
            return "AI API エラー (HTTP \(code)): \(body.prefix(200))"
        case .decodingFailed: return "AI レスポンスの解釈に失敗しました"
        case .generic(let msg): return msg
        }
    }
}

/// Pull the first {...} JSON block out of a possibly-noisy response.
func extractJSON(from text: String) -> String {
    if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
        return String(text[start...end])
    }
    return text
}
