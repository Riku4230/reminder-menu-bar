import EventKit
import SwiftUI

/// 親リマインダーから AI でサブタスク候補を取得し、ユーザーに編集・確認させてから一括追加する UI。
/// 起動時に自動で Claude を呼び、結果はユーザーが確定するまで EventKit には書き込まれない。
struct SubtaskGeneratorView: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var aiSettings: AISettings

    let parent: EKReminder
    let onClose: () -> Void

    private struct Candidate: Identifiable {
        let id = UUID()
        var title: String
        var memo: String
        var memoExpanded: Bool
    }

    @State private var candidates: [Candidate] = []
    @State private var isLoading = true
    @State private var isCommitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().opacity(0.4)

            content
                .frame(minHeight: 100, maxHeight: 320)

            Divider().opacity(0.4)

            footer
        }
        .frame(width: 340)
        .task { await generate() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MRTheme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text("AIでサブタスク生成")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                Text(parent.title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 22, height: 22)
                    .background(Color.black.opacity(0.04), in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("閉じる")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.regular)
                Text("提案を作成中…")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MRTheme.red)
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                Button("もう一度試す") {
                    Task { await generate() }
                }
                .buttonStyle(.borderedProminent)
                .tint(MRTheme.accent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach($candidates) { $candidate in
                        candidateRow(candidate: $candidate)
                    }

                    Button {
                        addEmpty()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("候補を追加")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func candidateRow(candidate: Binding<Candidate>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MRTheme.accent.opacity(0.8))

                TextField("サブタスク", text: candidate.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.primaryText)
                    .focused($focusedID, equals: candidate.id)
                    .disabled(isCommitting)

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        candidate.memoExpanded.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: candidate.memoExpanded.wrappedValue || !candidate.memo.wrappedValue.isEmpty ? "text.alignleft" : "text.append")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(candidate.memo.wrappedValue.isEmpty ? Color.tertiaryText : MRTheme.accent)
                        .frame(width: 18, height: 18)
                        .background(Color.black.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .help(candidate.memo.wrappedValue.isEmpty ? "メモを追加" : "メモを編集")

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        candidates.removeAll { $0.id == candidate.id }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.tertiaryText)
                        .frame(width: 18, height: 18)
                        .background(Color.black.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .help("候補から削除")
            }

            if candidate.memoExpanded.wrappedValue || !candidate.memo.wrappedValue.isEmpty {
                TextField("メモ（任意）", text: candidate.memo, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(1...4)
                    .padding(.leading, 19)
                    .disabled(isCommitting)
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if !isLoading && errorMessage == nil {
                Text("\(validCount) 件追加")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
            }
            Spacer()
            Button("キャンセル") {
                onClose()
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondaryText)
            .font(.system(size: 12))

            Button {
                Task { await commit() }
            } label: {
                HStack(spacing: 5) {
                    if isCommitting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(isCommitting ? "追加中…" : "追加する")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(MRTheme.accent)
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
            .disabled(isLoading || isCommitting || validCount == 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var validCount: Int {
        candidates.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    // MARK: - Actions

    private func generate() async {
        isLoading = true
        errorMessage = nil
        let memo = store.memo(for: parent)
        let result = await NLParser.generateSubtasks(
            parentTitle: parent.title,
            parentMemo: memo.isEmpty ? nil : memo,
            using: aiSettings.currentProvider()
        )
        if result.isEmpty {
            isLoading = false
            errorMessage = "AI からの応答が空でした。Claude Code がインストールされているか確認してください。"
            return
        }
        candidates = result.map {
            Candidate(title: $0.title, memo: $0.memo ?? "", memoExpanded: false)
        }
        isLoading = false
    }

    private func addEmpty() {
        let item = Candidate(title: "", memo: "", memoExpanded: false)
        candidates.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedID = item.id
        }
    }

    private func commit() async {
        let entries = candidates.compactMap { c -> (title: String, memo: String?)? in
            let title = c.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let memo = c.memo.trimmingCharacters(in: .whitespacesAndNewlines)
            return (title, memo.isEmpty ? nil : memo)
        }
        guard !entries.isEmpty else { return }
        isCommitting = true

        var failed: [String] = []
        for entry in entries {
            do {
                try await store.addSubtask(under: parent, title: entry.title, memo: entry.memo)
            } catch {
                failed.append(entry.title)
            }
        }

        isCommitting = false
        if !failed.isEmpty {
            errorMessage = "\(failed.count) 件の追加に失敗しました（\(failed.joined(separator: "、"))）"
            return
        }
        onClose()
    }
}
