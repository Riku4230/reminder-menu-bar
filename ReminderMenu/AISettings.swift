import Foundation
import SwiftUI

/// AI プロバイダの選択状態とモデル選択を保持。API キーは Keychain に逃がす。
@MainActor
final class AISettings: ObservableObject {
    private let providerKey = "ai.provider"
    private let modelPrefix = "ai.model."

    @Published var providerID: AIProviderID {
        didSet { UserDefaults.standard.set(providerID.rawValue, forKey: providerKey) }
    }

    /// モデルはプロバイダごとに別個に保持。次に切替えても元のモデル選択が残る。
    @Published private var modelByProvider: [AIProviderID: String] = [:]

    init() {
        if let raw = UserDefaults.standard.string(forKey: providerKey),
           let id = AIProviderID(rawValue: raw) {
            self.providerID = id
        } else {
            self.providerID = .claudeCode
        }
        for id in AIProviderID.allCases {
            let key = modelPrefix + id.rawValue
            if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
                modelByProvider[id] = stored
            } else {
                modelByProvider[id] = id.defaultModel
            }
        }
    }

    func model(for provider: AIProviderID) -> String {
        modelByProvider[provider] ?? provider.defaultModel
    }

    func setModel(_ model: String, for provider: AIProviderID) {
        modelByProvider[provider] = model
        UserDefaults.standard.set(model, forKey: modelPrefix + provider.rawValue)
        objectWillChange.send()
    }

    // MARK: - API Key

    func apiKey(for provider: AIProviderID) -> String? {
        guard provider.requiresAPIKey else { return nil }
        return KeychainStore.get(apiKeyAccount(provider))
    }

    func setAPIKey(_ key: String?, for provider: AIProviderID) {
        guard provider.requiresAPIKey else { return }
        KeychainStore.set(apiKeyAccount(provider), value: key)
        objectWillChange.send()
    }

    func hasAPIKey(_ provider: AIProviderID) -> Bool {
        guard provider.requiresAPIKey else { return true }
        if let key = apiKey(for: provider) { return !key.isEmpty }
        return false
    }

    private func apiKeyAccount(_ provider: AIProviderID) -> String {
        "apikey.\(provider.rawValue)"
    }

    // MARK: - Provider Resolution

    /// 現在選択中のプロバイダ実装を返す。未設定なら ClaudeCode にフォールバック。
    func currentProvider() -> AIProvider {
        switch providerID {
        case .claudeCode:
            return ClaudeCodeProvider()
        case .anthropic:
            return AnthropicAPIProvider(apiKey: apiKey(for: .anthropic) ?? "", model: model(for: .anthropic))
        case .openai:
            return OpenAIProvider(apiKey: apiKey(for: .openai) ?? "", model: model(for: .openai))
        case .gemini:
            return GeminiProvider(apiKey: apiKey(for: .gemini) ?? "", model: model(for: .gemini))
        }
    }
}
