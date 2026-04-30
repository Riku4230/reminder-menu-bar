import SwiftUI

/// Raycast 風クイック追加ウィンドウの SwiftUI View。
/// ホットキーで画面中央に表示し、タスクを素早く追加して閉じる。
struct QuickAddView: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var app: AppCoordinator
    @EnvironmentObject private var aiSettings: AISettings

    var onDismiss: () -> Void

    // MARK: - Composer state

    @FocusState private var inputFocused: Bool
    @State private var inputText = ""
    @State private var inputMode: InputMode = .normal
    @State private var isParsing = false
    @State private var optionsOpen = false

    // Options
    @State private var inputMemo = ""
    @State private var inputNewTag = ""
    @State private var inputTags: [String] = []
    @State private var inputFlagged = false
    @State private var inputURL = ""
    @State private var dueChoice: DueChoice = .none
    @State private var customDueDate = Date()
    @State private var customIncludesTime = false
    @State private var selectedPriority = 0
    @State private var selectedCalendarID: String?
    @State private var inputRecurrence: RecurrenceFrequency = .none
    @State private var inputEarlyReminder: EarlyReminderChoice = .none

    // Popover toggles
    @State private var showInputDueMenu = false
    @State private var showInputPriorityMenu = false
    @State private var showInputListMenu = false
    @State private var showInputRecurrenceMenu = false
    @State private var showInputAlarmMenu = false
    @State private var showAIProviderMenu = false

    // Success flash
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            if showSuccess {
                successView
            } else {
                composerBar
                if optionsOpen && inputMode != .ai {
                    Divider().opacity(0.3).padding(.horizontal, 12)
                    optionsPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .frame(width: 560)
        .background(.ultraThinMaterial)
        .background(MRTheme.Surface.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MRTheme.Border.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 40, y: 16)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(12)
        .onAppear { inputFocused = true }
    }

    // MARK: - Composer bar

    private var composerBar: some View {
        HStack(spacing: 10) {
            aiToggleButton

            TextField(
                inputMode == .ai ? "自然言語で追加…" : "新規リマインダー…",
                text: $inputText,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .lineLimit(1...6)
            .focused($inputFocused)
            .disabled(isParsing)
            .onKeyPress(.return) {
                if NSEvent.modifierFlags.contains(.shift) { return .ignored }
                if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
                   editor.hasMarkedText() { return .ignored }
                submitInput()
                return .handled
            }

            if inputMode != .ai {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        optionsOpen.toggle()
                    }
                } label: {
                    Image(systemName: optionsOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 26, height: 26)
                        .background(MRTheme.Surface.inset, in: Circle())
                        .overlay(Circle().stroke(MRTheme.Border.hairline, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }

            Button(action: submitInput) {
                ZStack {
                    Circle()
                        .fill(MRTheme.accent)
                        .frame(width: 30, height: 30)
                        .shadow(color: MRTheme.accent.opacity(0.38), radius: 10, y: 4)
                    if isParsing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - AI toggle

    private var aiToggleButton: some View {
        let isAI = inputMode == .ai
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                inputMode = isAI ? .normal : .ai
                if !isAI { optionsOpen = false }
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isAI ? Color.white : Color.secondaryText)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(isAI ? AnyShapeStyle(MRTheme.accent) : AnyShapeStyle(MRTheme.Surface.inset))
                )
                .overlay(
                    Circle().stroke(
                        isAI ? MRTheme.accent.opacity(0.7) : Color.black.opacity(0.1),
                        lineWidth: isAI ? 0.8 : 0.5
                    )
                )
                .shadow(color: isAI ? MRTheme.accent.opacity(0.35) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onLongPressGesture(minimumDuration: 0.35) {
            showAIProviderMenu = true
        }
        .popover(isPresented: $showAIProviderMenu, arrowEdge: .bottom) {
            aiProviderMenu
        }
    }

    private var aiProviderMenu: some View {
        ModernMenuSurface {
            VStack(spacing: 1) {
                ModernMenuTitle(label: "AI")
                ModernMenuRow(
                    icon: inputMode == .ai ? "textformat" : "sparkles",
                    label: inputMode == .ai ? "通常モードに戻す" : "AI モードに切替"
                ) {
                    showAIProviderMenu = false
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                        inputMode = inputMode == .ai ? .normal : .ai
                    }
                }
                ModernMenuDivider()
                ModernMenuSectionHeader(label: "プロバイダ")
                ForEach(AIProviderID.allCases) { provider in
                    ModernMenuRow(
                        icon: provider.requiresAPIKey && !aiSettings.hasAPIKey(provider) ? "exclamationmark.circle" : nil,
                        iconColor: provider.requiresAPIKey && !aiSettings.hasAPIKey(provider) ? MRTheme.yellow : .secondaryText,
                        label: provider.displayName,
                        trailingChecked: aiSettings.providerID == provider
                    ) {
                        aiSettings.providerID = provider
                        showAIProviderMenu = false
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                            inputMode = .ai
                        }
                    }
                }
            }
        }
        .frame(width: 230)
        .padding(6)
    }

    // MARK: - Options panel

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            TextField("メモ", text: $inputMemo, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.primaryText)
                .lineLimit(1...4)

            HStack(spacing: 6) {
                Image(systemName: "number")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                ForEach(inputTags, id: \.self) { tag in
                    HStack(spacing: 3) {
                        Text(tag)
                        Button {
                            inputTags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MRTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(MRTheme.accentSoft, in: Capsule())
                }
                TextField(inputTags.isEmpty ? "タグを追加" : "", text: $inputNewTag)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primaryText)
                    .onSubmit { commitInputTag() }
            }

            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.tertiaryText)
                TextField("URL", text: $inputURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primaryText)
            }

            actionRow
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actionRow: some View {
        HStack(spacing: 4) {
            dueChip
            if dueChoice != .none {
                Button {
                    dueChoice = .none
                    customIncludesTime = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.tertiaryText)
                        .frame(width: 16, height: 16)
                        .background(MRTheme.Surface.inset, in: Circle())
                }
                .buttonStyle(.plain)
            }
            priorityChip
            recurrenceChip
            alarmChip
            flagChip
            Spacer(minLength: 0)
            listChip
        }
    }

    // MARK: - Chips (期限・優先度・繰り返し・通知・フラグ・リスト)

    private var dueChip: some View {
        Button { showInputDueMenu = true } label: {
            ActionChip(
                systemName: "calendar",
                text: dueChipLabel,
                color: dueChoice != .none ? MRTheme.accent : .secondaryText,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputDueMenu, arrowEdge: .top) {
            dueMenu
        }
    }

    private var dueChipLabel: String {
        switch dueChoice {
        case .none: return "期限"
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .nextWeek: return "来週"
        case .custom:
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = customIncludesTime ? "M/d H:mm" : "M/d"
            return f.string(from: customDueDate)
        }
    }

    private var dueMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            ModernMenuTitle(label: "期限")
            ModernMenuRow(icon: "minus.circle", label: "なし", trailingChecked: dueChoice == .none) {
                dueChoice = .none; showInputDueMenu = false
            }
            ModernMenuRow(icon: "sun.max", label: "今日", trailingChecked: dueChoice == .today) {
                dueChoice = .today; showInputDueMenu = false
            }
            ModernMenuRow(icon: "sunrise", label: "明日", trailingChecked: dueChoice == .tomorrow) {
                dueChoice = .tomorrow; showInputDueMenu = false
            }
            ModernMenuRow(icon: "calendar.badge.clock", label: "来週", trailingChecked: dueChoice == .nextWeek) {
                dueChoice = .nextWeek; showInputDueMenu = false
            }
            ModernMenuDivider()
            ModernCalendar(selection: Binding(
                get: { customDueDate },
                set: { customDueDate = $0; dueChoice = .custom }
            ))
            HStack(spacing: MRTheme.Space.sm) {
                Text("時刻を含める")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                Spacer()
                MRModernSwitch(isOn: Binding(
                    get: { customIncludesTime },
                    set: { newValue in withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) { customIncludesTime = newValue } }
                ))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            if customIncludesTime {
                ModernTimePicker(date: $customDueDate)
            }
            HStack {
                Spacer()
                Button("完了") { showInputDueMenu = false }
                    .buttonStyle(.mr(.primary, size: .xs))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 270)
    }

    private var priorityChip: some View {
        Button { showInputPriorityMenu = true } label: {
            ActionChip(
                systemName: "exclamationmark.circle",
                text: priorityLabel(for: selectedPriority),
                color: priorityColor(for: selectedPriority),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputPriorityMenu, arrowEdge: .top) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "優先度")
                    ForEach([(0, "なし"), (9, "低"), (5, "中"), (1, "高")], id: \.0) { value, label in
                        ModernMenuRow(
                            icon: value == 0 ? "minus.circle" : "exclamationmark.circle.fill",
                            iconColor: priorityColor(for: value),
                            label: label,
                            trailingChecked: selectedPriority == value
                        ) {
                            selectedPriority = value
                            showInputPriorityMenu = false
                        }
                    }
                }
            }
            .frame(width: 160)
            .padding(6)
        }
    }

    private var recurrenceChip: some View {
        Button { showInputRecurrenceMenu = true } label: {
            ActionChip(
                systemName: "arrow.triangle.2.circlepath",
                text: inputRecurrence == .none ? "" : inputRecurrence.label,
                color: inputRecurrence != .none ? MRTheme.accent : .secondaryText
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputRecurrenceMenu, arrowEdge: .top) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "繰り返し")
                    ForEach(RecurrenceFrequency.allCases) { freq in
                        ModernMenuRow(
                            icon: freq.symbolName,
                            iconColor: freq == .none ? Color.tertiaryText : MRTheme.accent,
                            label: freq.label,
                            trailingChecked: inputRecurrence == freq
                        ) {
                            inputRecurrence = freq
                            showInputRecurrenceMenu = false
                        }
                    }
                }
            }
            .frame(width: 160)
            .padding(6)
        }
    }

    private var alarmChip: some View {
        Button { showInputAlarmMenu = true } label: {
            ActionChip(
                systemName: "bell",
                text: inputEarlyReminder == .none ? "" : inputEarlyReminder.shortLabel,
                color: inputEarlyReminder != .none ? MRTheme.accent : .secondaryText
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputAlarmMenu, arrowEdge: .top) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "通知")
                    ForEach(EarlyReminderChoice.allCases) { choice in
                        ModernMenuRow(
                            icon: choice == .none ? "minus.circle" : "bell.fill",
                            iconColor: choice == .none ? Color.tertiaryText : MRTheme.accent,
                            label: choice.label,
                            trailingChecked: inputEarlyReminder == choice
                        ) {
                            inputEarlyReminder = choice
                            showInputAlarmMenu = false
                        }
                    }
                }
            }
            .frame(width: 180)
            .padding(6)
        }
    }

    private var flagChip: some View {
        Button { inputFlagged.toggle() } label: {
            Image(systemName: inputFlagged ? "flag.fill" : "flag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(inputFlagged ? MRTheme.accent : Color.tertiaryText)
                .frame(width: 26, height: 22)
                .background(inputFlagged ? MRTheme.accentSoft : MRTheme.Surface.inset, in: Capsule())
                .overlay(Capsule().stroke(MRTheme.Border.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var listChip: some View {
        let id = selectedCalendarID ?? store.calendars.first?.id ?? ""
        let cal = store.calendars.first(where: { $0.id == id })
        return Button { showInputListMenu = true } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(cal?.color ?? Color.gray)
                    .frame(width: 7, height: 7)
                Text(cal?.title ?? "リスト")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .opacity(0.6)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(MRTheme.Surface.field, in: Capsule())
            .overlay(Capsule().stroke(MRTheme.Border.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputListMenu, arrowEdge: .top) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "リスト")
                    ForEach(store.calendars) { calendar in
                        ModernMenuRow(
                            leadingDot: calendar.color,
                            label: calendar.title,
                            trailingChecked: calendar.id == id
                        ) {
                            selectedCalendarID = calendar.id
                            showInputListMenu = false
                        }
                    }
                }
            }
            .frame(width: 220)
            .padding(6)
        }
    }

    // MARK: - Success view

    private var successView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(MRTheme.green)
            Text("追加しました")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primaryText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func submitInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isParsing else { return }

        if inputMode == .normal {
            do {
                let due = selectedDueDate()
                let created = try store.addReminder(
                    title: text,
                    dueDate: due.date,
                    includesTime: due.includesTime,
                    priority: selectedPriority,
                    calendarID: selectedCalendarID ?? store.selectedCalendarIDForCreation
                )
                let memoText = inputMemo.trimmingCharacters(in: .whitespacesAndNewlines)
                if !memoText.isEmpty { store.setMemo(created, memo: memoText) }
                for tag in inputTags { store.addTag(tag, to: created) }
                if inputFlagged { store.toggleFlagged(created) }
                let urlText = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !urlText.isEmpty, let url = URL(string: urlText) { store.setURL(created, url: url) }
                if inputRecurrence != .none { store.setRecurrence(created, frequency: inputRecurrence) }
                if inputEarlyReminder != .none { store.setEarlyReminder(created, choice: inputEarlyReminder) }
                flashSuccessAndDismiss()
            } catch {
                app.showToast(ToastMessage(kind: .failure, title: "追加できませんでした", detail: error.localizedDescription))
            }
        } else {
            Task { @MainActor in
                isParsing = true
                let drafts = await NLParser.parse(text, availableLists: store.calendars, using: aiSettings.currentProvider())
                if drafts.isEmpty {
                    app.showToast(ToastMessage(kind: .failure, title: "タスクを読み取れませんでした", detail: nil))
                    isParsing = false
                    return
                }
                do {
                    _ = try store.addDrafts(drafts, fallbackCalendarID: selectedCalendarID ?? store.selectedCalendarIDForCreation)
                    isParsing = false
                    flashSuccessAndDismiss()
                } catch {
                    app.showToast(ToastMessage(kind: .failure, title: "追加できませんでした", detail: error.localizedDescription))
                    isParsing = false
                }
            }
        }
    }

    private func flashSuccessAndDismiss() {
        withAnimation(.easeOut(duration: 0.15)) { showSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onDismiss()
        }
    }

    private func selectedDueDate() -> (date: Date?, includesTime: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch dueChoice {
        case .none: return (nil, false)
        case .today: return (today, false)
        case .tomorrow: return (calendar.date(byAdding: .day, value: 1, to: today), false)
        case .nextWeek: return (calendar.date(byAdding: .day, value: 7, to: today), false)
        case .custom: return (customDueDate, customIncludesTime)
        }
    }

    private func commitInputTag() {
        let trimmed = inputNewTag.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard !trimmed.isEmpty, !inputTags.contains(trimmed) else {
            inputNewTag = ""
            return
        }
        inputTags.append(trimmed)
        inputNewTag = ""
    }

    private func priorityLabel(for value: Int) -> String {
        switch value {
        case 1: return "高"
        case 5: return "中"
        case 9: return "低"
        default: return "優先度"
        }
    }

    private func priorityColor(for value: Int) -> Color {
        switch value {
        case 1: return MRTheme.red
        case 5: return MRTheme.yellow
        case 9: return MRTheme.blue
        default: return .secondaryText
        }
    }
}
