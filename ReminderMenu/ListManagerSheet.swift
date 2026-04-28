import SwiftUI

struct ListManagerSheet: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var app: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var editingID: String?
    @State private var draftName: String = ""
    @State private var draftColor: Color = MRTheme.accent
    @State private var deleteConfirm: ReminderCalendar?

    var body: some View {
        MRSettingsSurface(
            title: "リスト管理",
            subtitle: "リスト名、色、削除をまとめて管理します。",
            size: .standard,
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(spacing: MRTheme.Space.md) {
                    ForEach(store.calendars) { calendar in
                        if editingID == calendar.id {
                            editingRow(for: calendar)
                        } else {
                            row(for: calendar)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        } footer: {
            HStack(spacing: MRTheme.Space.md) {
                Text("\(store.calendars.count) 件のリスト")
                    .font(.system(size: MRTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Button("閉じる") { dismiss() }
                    .buttonStyle(.mr(.primary, size: .sm))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .alert(item: $deleteConfirm) { calendar in
            Alert(
                title: Text("「\(calendar.title)」を削除"),
                message: Text("このリスト内のすべてのリマインダーも削除されます。"),
                primaryButton: .destructive(Text("削除")) {
                    delete(calendar)
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    private func row(for calendar: ReminderCalendar) -> some View {
        MRCard(padding: MRTheme.Space.lg) {
            HStack(spacing: MRTheme.Space.lg) {
                Circle()
                    .fill(calendar.color)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.system(size: MRTheme.FontSize.label, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(1)
                    Text("\(calendar.count) 件 · \(calendar.sourceTitle)")
                        .font(.system(size: MRTheme.FontSize.footnote))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    draftName = calendar.title
                    draftColor = matchingColor(for: calendar.color)
                    editingID = calendar.id
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.mrIcon(dimension: 28))
                .help("編集")

                Button(role: .destructive) {
                    deleteConfirm = calendar
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.mrIcon(tint: MRTheme.red, dimension: 28))
                .help("削除")
            }
        }
    }

    private func editingRow(for calendar: ReminderCalendar) -> some View {
        MRCard(selected: true, padding: MRTheme.Space.lg) {
            VStack(alignment: .leading, spacing: MRTheme.Space.lg) {
                HStack(spacing: MRTheme.Space.md) {
                    Circle()
                        .fill(draftColor)
                        .frame(width: 14, height: 14)

                    MRStyledTextField {
                        TextField("リスト名", text: $draftName)
                            .onSubmit { save(calendar) }
                    }
                }

                HStack(spacing: MRTheme.Space.sm) {
                    ForEach(Array(MRTheme.listColors.enumerated()), id: \.offset) { _, color in
                        Button {
                            draftColor = color
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(sameColor(color, draftColor) ? 0.7 : 0), lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(MRTheme.Border.line, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button("キャンセル") {
                        editingID = nil
                    }
                    .buttonStyle(.mr(.secondary, size: .sm))

                    Button("保存") {
                        save(calendar)
                    }
                    .buttonStyle(.mr(.primary, size: .sm))
                    .keyboardShortcut(.defaultAction)
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save(_ calendar: ReminderCalendar) {
        do {
            try store.updateList(id: calendar.id, name: draftName, color: draftColor)
            editingID = nil
            app.showToast(ToastMessage(kind: .success, title: "リストを更新しました", detail: draftName))
        } catch {
            app.showToast(ToastMessage(kind: .failure, title: "更新できませんでした", detail: error.localizedDescription))
        }
    }

    private func delete(_ calendar: ReminderCalendar) {
        do {
            try store.deleteList(id: calendar.id)
            app.showToast(ToastMessage(kind: .success, title: "リストを削除しました", detail: calendar.title))
        } catch {
            app.showToast(ToastMessage(kind: .failure, title: "削除できませんでした", detail: error.localizedDescription))
        }
    }

    private func matchingColor(for current: Color) -> Color {
        if let match = MRTheme.listColors.first(where: { sameColor($0, current) }) {
            return match
        }
        return MRTheme.accent
    }

    private func sameColor(_ a: Color, _ b: Color) -> Bool {
        let aNS = MRTheme.nsColor(for: a)
        let bNS = MRTheme.nsColor(for: b)
        return aNS == bNS
    }
}
