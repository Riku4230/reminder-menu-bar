import AppKit
import SwiftUI

/// AI プロバイダの選択 + モデル選択 + API キー登録 UI。
/// API キーは Keychain に保存される。
struct AISettingsSheet: View {
    @EnvironmentObject private var aiSettings: AISettings
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: AIProviderID = .claudeCode
    @State private var apiKeyDrafts: [AIProviderID: String] = [:]
    @State private var revealKey: AIProviderID? = nil

    var body: some View {
        MRSettingsSurface(
            title: "AI 設定",
            subtitle: "AI モードで使うプロバイダ、モデル、API キーを管理します。",
            size: .preferences,
            onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: MRTheme.Space.lg) {
                MRInfoBanner(
                    systemImage: "lock.shield.fill",
                    text: "API キーは macOS Keychain に暗号化保存され、このデバイス内に閉じます (iCloud 同期なし)。",
                    tint: MRTheme.green
                )

                HStack(alignment: .top, spacing: MRTheme.Space.xl) {
                    providerList
                        .frame(width: 150)

                    Rectangle()
                        .fill(MRTheme.Border.hairline)
                        .frame(width: 0.5)

                    ScrollView {
                        providerDetail(selectedProvider)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        } footer: {
            HStack(spacing: MRTheme.Space.md) {
                Text("選択中: \(aiSettings.providerID.displayName)")
                    .font(.system(size: MRTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Button("閉じる") { dismiss() }
                    .buttonStyle(.mr(.primary, size: .sm))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            hydrateDrafts()
            selectedProvider = aiSettings.providerID
        }
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: MRTheme.Space.sm) {
            MRSectionHeader(title: "プロバイダ")
            ForEach(AIProviderID.allCases) { provider in
                providerListRow(provider)
            }
        }
    }

    private func providerListRow(_ provider: AIProviderID) -> some View {
        let isFocused = selectedProvider == provider
        let isActive = aiSettings.providerID == provider
        let isEnabled = aiSettings.hasAPIKey(provider)

        return Button {
            selectedProvider = provider
        } label: {
            HStack(spacing: MRTheme.Space.md) {
                Image(systemName: providerSymbol(provider))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isFocused ? MRTheme.accent : Color.secondaryText)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: MRTheme.Space.xs) {
                        Text(provider.displayName)
                            .font(.system(size: MRTheme.FontSize.label, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(MRTheme.green)
                        }
                    }
                    Text(isEnabled ? "有効" : "未設定")
                        .font(.system(size: MRTheme.FontSize.caption, weight: .medium))
                        .foregroundStyle(isEnabled ? MRTheme.green : MRTheme.yellow)
                }

                Spacer(minLength: 0)
            }
            .padding(MRTheme.Space.md)
            .background(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .fill(isFocused ? MRTheme.accentFaint : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .stroke(isFocused ? MRTheme.Border.accent : Color.clear, lineWidth: 0.7)
            )
            .contentShape(RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func providerDetail(_ provider: AIProviderID) -> some View {
        let isSelected = aiSettings.providerID == provider
        let isEnabled = aiSettings.hasAPIKey(provider)

        return VStack(alignment: .leading, spacing: MRTheme.Space.lg) {
            MRCard(selected: isSelected, padding: MRTheme.Space.xl) {
                VStack(alignment: .leading, spacing: MRTheme.Space.xl) {
                    HStack(alignment: .center, spacing: MRTheme.Space.md) {
                        Image(systemName: providerSymbol(provider))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? MRTheme.accent : Color.secondaryText)
                            .frame(width: 26)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(provider.displayName)
                                .font(.system(size: MRTheme.FontSize.heading, weight: .bold))
                                .foregroundStyle(Color.primaryText)
                            Text(providerTagline(provider))
                                .font(.system(size: MRTheme.FontSize.footnote))
                                .foregroundStyle(Color.secondaryText)
                        }

                        Spacer()
                    }

                    HStack(spacing: MRTheme.Space.sm) {
                        MRPill(
                            label: isEnabled ? "有効" : "未設定",
                            style: isEnabled ? .success : .warning
                        )

                        if isSelected {
                            MRPill(label: "選択中", systemImage: "checkmark", style: .success)
                        } else {
                            Button("使う") {
                                aiSettings.providerID = provider
                            }
                            .buttonStyle(.mr(.primary, size: .sm))
                            .disabled(!isEnabled)
                            .help(isEnabled ? "このプロバイダを使う" : "先に API キーを保存してください")
                        }
                    }

                    Text(providerDescription(provider))
                        .font(.system(size: MRTheme.FontSize.footnote))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !provider.availableModels.isEmpty {
                        modelRow(provider)
                    }

                    if provider.requiresAPIKey {
                        apiKeyEditor(provider)
                    }
                }
            }
        }
        .padding(.bottom, MRTheme.Space.xs)
    }

    private func modelRow(_ provider: AIProviderID) -> some View {
        MRFieldRow(label: "モデル") {
            ModelDropdown(
                models: provider.availableModels,
                selection: Binding(
                    get: { aiSettings.model(for: provider) },
                    set: { aiSettings.setModel($0, for: provider) }
                )
            )
        }
    }

    private func apiKeyEditor(_ provider: AIProviderID) -> some View {
        VStack(alignment: .leading, spacing: MRTheme.Space.md) {
            HStack(spacing: MRTheme.Space.sm) {
                Text("API キー")
                    .font(.system(size: MRTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)

                Spacer()

                if let url = provider.apiKeyURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9, weight: .semibold))
                            Text("キーを取得")
                                .font(.system(size: MRTheme.FontSize.footnote, weight: .semibold))
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
                .frame(maxWidth: .infinity)

                Button {
                    revealKey = (revealKey == provider) ? nil : provider
                } label: {
                    Image(systemName: revealKey == provider ? "eye.slash" : "eye")
                }
                .buttonStyle(.mrIcon())
                .help("表示 / 非表示")

                Button("保存") {
                    saveAPIKey(provider)
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

    private func saveAPIKey(_ provider: AIProviderID) {
        let value = (apiKeyDrafts[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        aiSettings.setAPIKey(value.isEmpty ? nil : value, for: provider)
    }

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
        case .anthropic: return "sparkles"
        case .openai: return "circle.hexagongrid.fill"
        case .gemini: return "atom"
        }
    }

    private func providerTagline(_ provider: AIProviderID) -> String {
        switch provider {
        case .claudeCode: return "ローカルの Claude Code CLI を利用"
        case .anthropic: return "Anthropic API キーで直接実行"
        case .openai: return "OpenAI Responses API を利用"
        case .gemini: return "Google Gemini API を利用"
        }
    }

    private func providerDescription(_ provider: AIProviderID) -> String {
        switch provider {
        case .claudeCode:
            return "Claude Code は CLI のサブスク認証 (Max/Team/Enterprise) または ANTHROPIC_API_KEY を再利用します。Hutch 側で API キーは保持しません。"
        default:
            return "このプロバイダを使うには API キーの保存が必要です。モデルはここで選択でき、保存したキーは Keychain から読み込まれます。"
        }
    }
}

private struct ModelDropdown: View {
    let models: [String]
    @Binding var selection: String

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: MRTheme.Space.sm) {
                Text(selection.isEmpty ? "モデルを選択" : selection)
                    .font(.system(size: MRTheme.FontSize.body, weight: .semibold))
                    .foregroundStyle(selection.isEmpty ? Color.tertiaryText : Color.primaryText)
                    .lineLimit(1)
                Spacer(minLength: MRTheme.Space.sm)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(MRTheme.accent)
            }
            .padding(.horizontal, MRTheme.Space.md + 2)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .fill(MRTheme.Surface.field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous)
                    .stroke(isOpen ? MRTheme.Border.accent : MRTheme.Border.line, lineWidth: isOpen ? 1 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: MRTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "モデル")
                    ForEach(models, id: \.self) { model in
                        ModernMenuRow(
                            icon: selection == model ? "checkmark" : nil,
                            iconColor: MRTheme.accent,
                            label: model
                        ) {
                            selection = model
                            isOpen = false
                        }
                    }
                }
            }
            .frame(width: 220)
            .padding(6)
        }
    }
}
