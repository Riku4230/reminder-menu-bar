import SwiftUI

/// AI プロバイダの選択 + モデル選択 + API キー登録 UI。
/// API キーは Keychain に保存される。
struct AISettingsSheet: View {
    @EnvironmentObject private var aiSettings: AISettings
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyDrafts: [AIProviderID: String] = [:]
    @State private var revealKey: AIProviderID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MRTheme.Space.lg) {
            header
            VStack(alignment: .leading, spacing: 4) {
                Text("Nudge が AI モードで使うプロバイダを選びます。")
                    .font(.system(size: MRTheme.FontSize.footnote))
                    .foregroundStyle(Color.secondaryText)
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MRTheme.green)
                    Text("API キーは macOS Keychain に暗号化保存され、このデバイス内に閉じます (iCloud 同期なし)。")
                        .font(.system(size: MRTheme.FontSize.caption))
                        .foregroundStyle(Color.secondaryText)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: MRTheme.Space.md) {
                    ForEach(AIProviderID.allCases) { provider in
                        providerCard(provider)
                    }
                }
                .padding(.bottom, MRTheme.Space.xs)
            }
            .scrollIndicators(.hidden)
        }
        .padding(MRTheme.Space.xl + 2)
        .frame(width: 480, height: 580)
        .background(MRTheme.Surface.background)
        .onAppear { hydrateDrafts() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI プロバイダ設定")
                    .font(.system(size: MRTheme.FontSize.title, weight: .bold))
                Text("選択中: \(aiSettings.providerID.displayName)")
                    .font(.system(size: MRTheme.FontSize.footnote))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            MRCloseButton { dismiss() }
        }
    }

    // MARK: - Provider Card

    @ViewBuilder
    private func providerCard(_ provider: AIProviderID) -> some View {
        let isSelected = aiSettings.providerID == provider
        let isEnabled = aiSettings.hasAPIKey(provider)
        MRCard(selected: isSelected, padding: MRTheme.Space.lg) {
            VStack(alignment: .leading, spacing: MRTheme.Space.lg) {
                providerHeader(provider, isSelected: isSelected, isEnabled: isEnabled)
                if !provider.availableModels.isEmpty {
                    modelRow(provider)
                }
                if provider.requiresAPIKey {
                    apiKeyField(provider)
                } else {
                    Text("Claude Code は CLI のサブスク認証 (Max/Team/Enterprise) または ANTHROPIC_API_KEY を再利用します。Nudge 側で API キーは保持しません。")
                        .font(.system(size: MRTheme.FontSize.footnote))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.vertical, MRTheme.Space.xxs)
                }
            }
        }
    }

    @ViewBuilder
    private func providerHeader(_ provider: AIProviderID, isSelected: Bool, isEnabled: Bool) -> some View {
        HStack(spacing: MRTheme.Space.md) {
            Image(systemName: providerSymbol(provider))
                .font(.system(size: MRTheme.FontSize.label, weight: .semibold))
                .foregroundStyle(isSelected ? MRTheme.accent : Color.secondaryText)
                .frame(width: 18)
            Text(provider.displayName)
                .font(.system(size: MRTheme.FontSize.label + 0.5, weight: .semibold))
            MRPill(label: isEnabled ? "有効" : "無効",
                   style: isEnabled ? .success : .warning)
            Spacer()
            if isSelected {
                MRPill(label: "選択中", systemImage: "checkmark", style: .success)
            } else {
                Button("使う") { aiSettings.providerID = provider }
                    .buttonStyle(.mr(.primary, size: .sm))
            }
        }
    }

    @ViewBuilder
    private func modelRow(_ provider: AIProviderID) -> some View {
        HStack(spacing: MRTheme.Space.md) {
            Text("モデル")
                .font(.system(size: MRTheme.FontSize.footnote, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 56, alignment: .leading)
            Picker("", selection: Binding(
                get: { aiSettings.model(for: provider) },
                set: { aiSettings.setModel($0, for: provider) }
            )) {
                ForEach(provider.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func apiKeyField(_ provider: AIProviderID) -> some View {
        VStack(alignment: .leading, spacing: MRTheme.Space.sm) {
            HStack(spacing: MRTheme.Space.sm) {
                Text("API キー")
                    .font(.system(size: MRTheme.FontSize.footnote, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                if let url = provider.apiKeyURL {
                    Link(destination: url) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9, weight: .semibold))
                            Text("キーを取得")
                                .font(.system(size: MRTheme.FontSize.footnote))
                        }
                        .foregroundStyle(MRTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: MRTheme.Space.sm) {
                MRStyledTextField {
                    if revealKey == provider {
                        TextField("sk-...", text: bindingForDraft(provider))
                    } else {
                        SecureField("sk-...", text: bindingForDraft(provider))
                    }
                }

                Button {
                    revealKey = (revealKey == provider) ? nil : provider
                } label: {
                    Image(systemName: revealKey == provider ? "eye.slash" : "eye")
                }
                .buttonStyle(.mrIcon())
                .help("表示 / 非表示")

                Button("保存") {
                    let v = (apiKeyDrafts[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    aiSettings.setAPIKey(v.isEmpty ? nil : v, for: provider)
                }
                .buttonStyle(.mr(.secondary, size: .sm))

                Button {
                    aiSettings.setAPIKey(nil, for: provider)
                    apiKeyDrafts[provider] = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.mrIcon(tint: MRTheme.red))
                .help("API キーを削除")
            }
        }
    }

    // MARK: - Helpers

    private func bindingForDraft(_ provider: AIProviderID) -> Binding<String> {
        Binding(
            get: { apiKeyDrafts[provider] ?? "" },
            set: { apiKeyDrafts[provider] = $0 }
        )
    }

    private func hydrateDrafts() {
        for provider in AIProviderID.allCases where provider.requiresAPIKey {
            apiKeyDrafts[provider] = aiSettings.apiKey(for: provider) ?? ""
        }
    }

    private func providerSymbol(_ provider: AIProviderID) -> String {
        switch provider {
        case .claudeCode: return "terminal"
        case .anthropic:  return "sparkles"
        case .openai:     return "circle.hexagongrid.fill"
        case .gemini:     return "atom"
        }
    }
}
