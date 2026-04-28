import EventKit
import SwiftUI

struct ReminderRow: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var aiSettings: AISettings

    let reminder: EKReminder
    var indentLevel: Int = 0
    /// `indentLevel == 0` で出ているが本来は誰かの子タスクのとき true。
    /// 親が同じグループに居なくてフラットに描画されるケースを区別するために使う。
    var isOrphanedChild: Bool = false

    @State private var isExpanded = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @State private var editedMemo = ""
    @State private var newTagText = ""
    @State private var showDatePopover = false
    @State private var isCompleting = false
    @State private var completionTask: Task<Void, Never>?
    @State private var showPriorityMenu = false
    @State private var showRecurrenceMenu = false
    @State private var showAlarmMenu = false
    @State private var editedURL: String = ""
    @State private var isAddingSubtask = false
    @State private var newSubtaskText = ""
    @State private var subtaskInFlight = false
    @State private var showSubtaskGenerator = false
    @FocusState private var titleFocused: Bool
    @FocusState private var memoFocused: Bool
    @FocusState private var tagFocused: Bool
    @FocusState private var subtaskFocused: Bool

    private var displayedAsCompleted: Bool {
        reminder.isCompleted || isCompleting
    }

    private var progressState: ProgressState {
        // 完了アニメーション中は実体としては未完了でも視覚的には完了扱い
        if isCompleting { return .completed }
        return store.progressState(of: reminder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 11) {
                checkbox.padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    titleArea
                    if hasMeta {
                        metaRow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if store.isFlagged(reminder) || isExpanded {
                    flagButton.padding(.top, 0)
                }
            }

            if isExpanded {
                expandedDetails
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .padding(.leading, CGFloat(indentLevel) * 22)
        .overlay(alignment: .leading) {
            if indentLevel > 0 {
                Rectangle()
                    .fill(MRTheme.accent.opacity(0.28))
                    .frame(width: 1.5)
                    .padding(.leading, CGFloat(indentLevel) * 22 - 10)
                    .padding(.vertical, 8)
            }
        }
        .contentShape(Rectangle())
        .opacity(rowOpacity)
        .scaleEffect(isCompleting ? 0.985 : 1, anchor: .leading)
        .onTapGesture {
            handleRowTap()
        }
        .onDrag {
            NSItemProvider(object: reminder.calendarItemIdentifier as NSString)
        }
        .onDisappear { completionTask?.cancel() }
    }

    private func handleRowTap() {
        // Commit any in-progress edits before toggling
        if isEditingTitle {
            commitTitle()
        }
        if memoFocused {
            let current = store.memo(for: reminder)
            if editedMemo != current {
                store.setMemo(reminder, memo: editedMemo)
            }
            memoFocused = false
        }
        if tagFocused {
            if !newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                commitNewTag()
            }
            tagFocused = false
        }
        // URL: commit if changed
        let currentURLString = reminder.url?.absoluteString ?? ""
        if editedURL != currentURLString {
            commitURL()
        }
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
            isExpanded.toggle()
        }
    }

    private var rowOpacity: Double {
        if reminder.isCompleted { return 0.5 }
        if isCompleting { return 0.55 }
        return 1
    }

    private var hasMeta: Bool {
        store.dueLabel(for: reminder) != nil
            || store.priorityLabel(for: reminder) != nil
            || !store.displayTags(for: reminder).isEmpty
            || progressState == .inProgress
            || store.parent(of: reminder) != nil
    }

    // MARK: - Checkbox (3 states: 未着手 / 進行中 / 完了)

    private var checkbox: some View {
        Button {
            handleCheckboxTap()
        } label: {
            ZStack {
                let calColor = store.color(for: reminder.calendar)
                Circle()
                    .stroke(calColor.opacity(progressState == .inProgress ? 0.25 : 1.0), lineWidth: 1.6)
                    .frame(width: 18, height: 18)

                switch progressState {
                case .notStarted:
                    EmptyView()
                case .inProgress:
                    // 進行中: 短い弧が外周を回るスピナー風表現
                    SpinnerArc(color: calColor)
                        .frame(width: 18, height: 18)
                        .transition(.opacity)
                case .completed:
                    Circle()
                        .fill(calColor)
                        .frame(width: 18, height: 18)
                        .transition(.scale.combined(with: .opacity))
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(checkboxHelp)
    }

    private var checkboxHelp: String {
        if isCompleting { return "完了をキャンセル" }
        switch progressState {
        case .notStarted: return "進行中にする"
        case .inProgress: return "完了にする"
        case .completed: return "未着手に戻す"
        }
    }

    private func handleCheckboxTap() {
        // 完了の最中なら、その確定をキャンセル
        if isCompleting {
            completionTask?.cancel()
            completionTask = nil
            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                isCompleting = false
            }
            return
        }

        switch store.progressState(of: reminder) {
        case .notStarted:
            // 未着手 → 進行中（即時）
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                store.setProgressState(.inProgress, for: reminder)
            }
        case .inProgress:
            // 進行中 → 完了（750ms の確定アニメーション付き）
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                isCompleting = true
                isExpanded = false
            }
            let task = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 750_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    store.setProgressState(.completed, for: reminder)
                    isCompleting = false
                }
            }
            completionTask = task
        case .completed:
            // 完了 → 未着手（即時）
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                store.setProgressState(.notStarted, for: reminder)
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    private var titleArea: some View {
        if isEditingTitle {
            VStack(alignment: .leading, spacing: 0) {
                TextField("タイトル", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.primaryText)
                    .focused($titleFocused)
                    .onSubmit { commitTitle() }
                    .onExitCommand { cancelTitleEdit() }

                Rectangle()
                    .fill(MRTheme.accent)
                    .frame(height: 1)
                    .padding(.top, 2)
            }
            .onChange(of: titleFocused) { _, focused in
                if !focused && isEditingTitle {
                    commitTitle()
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if isOrphanedChild {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MRTheme.accent.opacity(0.7))
                        .help("これはサブタスクです（親は別グループにあります）")
                }
                Text(reminder.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(displayedAsCompleted ? Color.secondaryText : Color.primaryText)
                    .lineLimit(2)
                    .strikethrough(displayedAsCompleted, color: .secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { beginTitleEdit() }
        }
    }

    // MARK: - Meta — minimal, no card

    private var metaRow: some View {
        HStack(spacing: 8) {
            if progressState == .inProgress {
                MetaItem(systemName: "circle.inset.filled", text: "進行中", color: MRTheme.accent)
            }
            if let parent = store.parent(of: reminder) {
                MetaItem(
                    systemName: "arrow.turn.left.up",
                    text: parent.title,
                    color: .secondaryText
                )
            }
            if let dueLabel = store.dueLabel(for: reminder) {
                let isToday = dueLabel.hasPrefix("今日") && !reminder.isCompleted
                MetaItem(
                    systemName: "calendar",
                    text: dueLabel,
                    color: isToday ? MRTheme.accent : .secondaryText
                )
            }
            if let priority = store.priorityLabel(for: reminder) {
                MetaItem(systemName: "exclamationmark.circle.fill", text: priority, color: store.priorityColor(for: reminder))
            }
            ForEach(store.displayTags(for: reminder), id: \.self) { tag in
                MetaItem(systemName: "number", text: tag, color: MRTheme.accent)
            }
        }
        .font(.system(size: 11))
    }

    // MARK: - Flag toggle

    private var flagButton: some View {
        Button {
            store.toggleFlagged(reminder)
        } label: {
            Image(systemName: store.isFlagged(reminder) ? "flag.fill" : "flag")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.isFlagged(reminder) ? MRTheme.accent : Color.tertiaryText)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(store.isFlagged(reminder) ? "フラグを外す" : "フラグを付ける")
    }

    // MARK: - Expanded details

    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            memoField
            tagField
            urlField
            actionRow
            parentLinkRow
            subtasksList
            if indentLevel == 0 {
                subtaskSection
            }
        }
        .padding(.top, 4)
        .padding(.leading, 29)
    }

    /// 子タスク表示時に親タスクへのリンク行を出す。
    @ViewBuilder
    private var parentLinkRow: some View {
        if let parent = store.parent(of: reminder) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.left.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MRTheme.accent)
                Text("親:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
                Text(parent.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.primaryText)
                    .strikethrough(parent.isCompleted, color: .secondaryText)
                Spacer()
            }
            .padding(.vertical, 2)
        }
    }

    /// 親タスク展開時にサブタスク一覧を出す。
    @ViewBuilder
    private var subtasksList: some View {
        let subs = store.subtasks(of: reminder)
        if !subs.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.indent")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                    Text("サブタスク \(subs.count) 件")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .tracking(0.3)
                }
                ForEach(subs, id: \.calendarItemIdentifier) { sub in
                    HStack(spacing: 6) {
                        Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 10))
                            .foregroundStyle(sub.isCompleted ? MRTheme.accent : Color.secondaryText)
                        Text(sub.title)
                            .font(.system(size: 11.5))
                            .foregroundStyle(sub.isCompleted ? Color.secondaryText : Color.primaryText)
                            .strikethrough(sub.isCompleted, color: .secondaryText)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var subtaskSection: some View {
        if isAddingSubtask {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MRTheme.accent)
                TextField("サブタスクを追加", text: $newSubtaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.primaryText)
                    .focused($subtaskFocused)
                    .disabled(subtaskInFlight)
                    .onKeyPress(.return) {
                        // IME 変換中の Enter は確定として通す
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
                           editor.hasMarkedText() {
                            return .ignored
                        }
                        commitNewSubtask()
                        return .handled
                    }
                    .onExitCommand { cancelSubtaskAdd() }
                if subtaskInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } else {
            HStack(spacing: 6) {
                Button {
                    beginSubtaskAdd()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("サブタスクを追加")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.85), in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("このタスクの下にサブタスクを追加")

                Button {
                    showSubtaskGenerator = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("AIで生成")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(MRTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MRTheme.accentSoft, in: Capsule())
                    .overlay(Capsule().stroke(MRTheme.accent.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("AI に親タスクを分解してもらう")
                .popover(isPresented: $showSubtaskGenerator, arrowEdge: .top) {
                    SubtaskGeneratorView(parent: reminder) {
                        showSubtaskGenerator = false
                    }
                    .environmentObject(store)
                    .environmentObject(aiSettings)
                }
            }
        }
    }

    private func beginSubtaskAdd() {
        newSubtaskText = ""
        withAnimation(.easeOut(duration: 0.15)) {
            isAddingSubtask = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            subtaskFocused = true
        }
    }

    private func cancelSubtaskAdd() {
        withAnimation { isAddingSubtask = false }
        subtaskFocused = false
        newSubtaskText = ""
    }

    private func commitNewSubtask() {
        let title = newSubtaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !subtaskInFlight else { return }
        subtaskInFlight = true
        Task { @MainActor in
            do {
                try await store.addSubtask(under: reminder, title: title)
                newSubtaskText = ""
                subtaskInFlight = false
                subtaskFocused = true
            } catch {
                store.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                subtaskInFlight = false
                subtaskFocused = true
            }
        }
    }

    private var urlField: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)

            TextField("URL", text: $editedURL)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primaryText)
                .onAppear {
                    editedURL = reminder.url?.absoluteString ?? ""
                }
                .onSubmit { commitURL() }
                .onChange(of: editedURL) { _, _ in
                    // commit on submit; live changes only saved on commit
                }

            if let url = reminder.url, !editedURL.isEmpty {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MRTheme.accent)
                        .frame(width: 18, height: 18)
                        .background(MRTheme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .help("URLを開く")
            }
        }
    }

    private func commitURL() {
        let trimmed = editedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.setURL(reminder, url: nil)
        } else if let url = URL(string: trimmed) {
            store.setURL(reminder, url: url)
        }
    }

    private var memoField: some View {
        TextField("メモ", text: $editedMemo, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Color.primaryText)
            .focused($memoFocused)
            .lineLimit(1...6)
            .onAppear { editedMemo = store.memo(for: reminder) }
            .onChange(of: memoFocused) { _, focused in
                if !focused {
                    let current = store.memo(for: reminder)
                    if editedMemo != current {
                        store.setMemo(reminder, memo: editedMemo)
                    }
                }
            }
    }

    private var tagField: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)

            TextField("タグを追加", text: $newTagText)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primaryText)
                .focused($tagFocused)
                .onSubmit { commitNewTag() }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 4) {
            Button {
                showDatePopover = true
            } label: {
                ActionChip(
                    systemName: "calendar",
                    text: store.dueLabel(for: reminder) ?? ""
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePopover, arrowEdge: .bottom) {
                DateTimePopover(reminder: reminder) { showDatePopover = false }
                    .environmentObject(store)
            }
            .help("日付・時刻")

            if store.dueDate(for: reminder) != nil {
                Button {
                    store.updateReminder(reminder, title: reminder.title, dueDate: nil, includesTime: false)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.tertiaryText)
                        .frame(width: 16, height: 16)
                        .background(Color.black.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
                .help("期限を外す")
            }

            Button {
                showPriorityMenu = true
            } label: {
                ActionChip(
                    systemName: "exclamationmark.circle",
                    text: store.priorityLabel(for: reminder) ?? "",
                    color: store.priorityLabel(for: reminder) != nil
                        ? store.priorityColor(for: reminder)
                        : .secondaryText
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPriorityMenu, arrowEdge: .top) {
                priorityMenuContent
            }
            .help("優先度")

            Button {
                showRecurrenceMenu = true
            } label: {
                let freq = store.recurrenceFrequency(for: reminder)
                ActionChip(
                    systemName: "arrow.triangle.2.circlepath",
                    text: freq == .none ? "" : freq.label,
                    color: freq != .none ? MRTheme.accent : .secondaryText
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showRecurrenceMenu, arrowEdge: .top) {
                recurrenceMenuContent
            }
            .help("繰り返し")

            Button {
                showAlarmMenu = true
            } label: {
                let choice = store.earlyReminderChoice(for: reminder)
                ActionChip(
                    systemName: "bell",
                    text: choice == .none ? "" : choice.shortLabel,
                    color: choice != .none ? MRTheme.accent : .secondaryText
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showAlarmMenu, arrowEdge: .top) {
                alarmMenuContent
            }
            .help("通知")

            Spacer(minLength: 0)

            Button(role: .destructive) {
                withAnimation { store.removeReminder(reminder) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MRTheme.red)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("削除")
        }
    }

    private var alarmMenuContent: some View {
        ModernMenuSurface {
            VStack(spacing: 1) {
                ModernMenuTitle(label: "通知")
                ForEach(EarlyReminderChoice.allCases) { choice in
                    ModernMenuRow(
                        icon: choice == .none ? "minus.circle" : "bell.fill",
                        iconColor: choice == .none ? Color.tertiaryText : MRTheme.accent,
                        label: choice.label,
                        trailingChecked: store.earlyReminderChoice(for: reminder) == choice
                    ) {
                        store.setEarlyReminder(reminder, choice: choice)
                        showAlarmMenu = false
                    }
                }
            }
        }
        .frame(width: 180)
        .padding(6)
    }

    private var recurrenceMenuContent: some View {
        ModernMenuSurface {
            VStack(spacing: 1) {
                ModernMenuTitle(label: "繰り返し")
                ForEach(RecurrenceFrequency.allCases) { freq in
                    ModernMenuRow(
                        icon: freq.symbolName,
                        iconColor: freq == .none ? Color.tertiaryText : MRTheme.accent,
                        label: freq.label,
                        trailingChecked: store.recurrenceFrequency(for: reminder) == freq
                    ) {
                        store.setRecurrence(reminder, frequency: freq)
                        showRecurrenceMenu = false
                    }
                }
            }
        }
        .frame(width: 160)
        .padding(6)
    }

    // MARK: - Helpers

    private var priorityMenuContent: some View {
        ModernMenuSurface {
            VStack(spacing: 1) {
                ModernMenuTitle(label: "優先度")
                ForEach(PriorityChoice.allCases) { choice in
                    ModernMenuRow(
                        icon: choice == .none ? "minus.circle" : "exclamationmark.circle.fill",
                        iconColor: priorityIconColor(for: choice),
                        label: choice.label,
                        trailingChecked: currentPriorityChoice == choice
                    ) {
                        store.setPriority(reminder, to: choice.rawValue)
                        showPriorityMenu = false
                    }
                }
            }
        }
        .frame(width: 160)
        .padding(6)
    }

    private func priorityIconColor(for choice: PriorityChoice) -> Color {
        switch choice {
        case .none: return Color.tertiaryText
        case .low: return MRTheme.blue
        case .medium: return MRTheme.yellow
        case .high: return MRTheme.red
        }
    }

    private var currentPriorityChoice: PriorityChoice {
        switch reminder.priority {
        case 1...4: return .high
        case 5: return .medium
        case 6...9: return .low
        default: return .none
        }
    }

    private func beginTitleEdit() {
        editedTitle = reminder.title
        withAnimation(.easeOut(duration: 0.15)) {
            isEditingTitle = true
            isExpanded = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            titleFocused = true
        }
    }

    private func commitTitle() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != reminder.title {
            store.updateReminder(
                reminder,
                title: trimmed,
                dueDate: store.dueDate(for: reminder),
                includesTime: store.includesTime(reminder)
            )
        }
        withAnimation { isEditingTitle = false }
        titleFocused = false
    }

    private func cancelTitleEdit() {
        withAnimation { isEditingTitle = false }
        titleFocused = false
    }

    private func commitNewTag() {
        let value = newTagText
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        store.addTag(value, to: reminder)
        newTagText = ""
    }
}

// MARK: - Inline meta item (no chip background)

// MARK: - In-progress spinner arc

/// 「進行中」を表すマーク。状態変化 / 再描画時に **1 周だけ** 回って止まる。
/// 静止後は外周上部に弧が固定され、それ自体が「進行中」のサインとして残る。
/// 常時回転だとリスト内で複数同時に動いて視覚ノイズになるため、フィードバック的な短アニメに留める。
private struct SpinnerArc: View {
    let color: Color
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(color, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            .rotationEffect(.degrees(angle))
            .onAppear {
                // 一度だけ一周してそのまま静止（easeOut でラスト緩やかに減速）
                withAnimation(.easeOut(duration: 1.4)) {
                    angle = 360
                }
            }
    }
}

private struct MetaItem: View {
    var systemName: String
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Date / Time Popover

struct DateTimePopover: View {
    @EnvironmentObject private var store: ReminderStore
    let reminder: EKReminder
    let onClose: () -> Void

    @State private var hasDueDate: Bool = false
    @State private var includesTime: Bool = false
    @State private var pickedDate: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle("期限を設定", isOn: $hasDueDate.animation())
                    .font(.system(size: 12, weight: .semibold))
                    .toggleStyle(.switch)
                    .tint(MRTheme.accent)
                Spacer()
            }

            if hasDueDate {
                ModernCalendar(selection: $pickedDate)

                Divider().opacity(0.4)

                Toggle("時刻を含める", isOn: $includesTime.animation())
                    .font(.system(size: 11.5, weight: .semibold))
                    .toggleStyle(.switch)
                    .tint(MRTheme.accent)

                if includesTime {
                    ModernTimePicker(date: $pickedDate)
                }
            }

            HStack {
                Button("キャンセル") { onClose() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.secondaryText)
                    .font(.system(size: 12))
                Spacer()
                Button("適用") {
                    apply()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(MRTheme.accent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 280)
        .onAppear { seed() }
    }

    private func seed() {
        if let date = store.dueDate(for: reminder) {
            hasDueDate = true
            includesTime = store.includesTime(reminder)
            pickedDate = date
        } else {
            hasDueDate = false
            includesTime = false
            pickedDate = Date()
        }
    }

    private func apply() {
        guard hasDueDate else {
            store.updateReminder(reminder, title: reminder.title, dueDate: nil, includesTime: false)
            return
        }
        store.updateReminder(
            reminder,
            title: reminder.title,
            dueDate: pickedDate,
            includesTime: includesTime
        )
    }
}

// MARK: - Modern Calendar

struct ModernCalendar: View {
    @Binding var selection: Date
    @State private var displayMonth: Date

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.locale = Locale(identifier: "ja_JP")
        return cal
    }()
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    init(selection: Binding<Date>) {
        _selection = selection
        _displayMonth = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayRow
            grid
        }
    }

    private var header: some View {
        HStack {
            Text(monthLabel)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color.primaryText)
            Spacer()
            navButton(systemName: "chevron.left") { changeMonth(-1) }
            navButton(systemName: "circle.fill", small: true) {
                let now = Date()
                withAnimation(.easeInOut(duration: 0.15)) {
                    displayMonth = now
                }
                selection = now
            }
            navButton(systemName: "chevron.right") { changeMonth(1) }
        }
    }

    private func navButton(systemName: String, small: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: small ? 5 : 9, weight: .bold))
                .foregroundStyle(small ? MRTheme.accent : Color.secondaryText)
                .frame(width: 20, height: 20)
                .background(Color.black.opacity(0.04), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(weekdays[i])
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(weekdayColor(i))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return Color(red: 0.86, green: 0.36, blue: 0.36) }
        if index == 6 { return Color(red: 0.36, green: 0.56, blue: 0.86) }
        return Color.tertiaryText
    }

    private var grid: some View {
        let days = makeDays()
        return VStack(spacing: 3) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let day = days[row * 7 + col]
                        DayCell(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selection),
                            calendar: calendar
                        ) {
                            withAnimation(.easeOut(duration: 0.12)) {
                                selection = day.date
                                if !day.isInMonth {
                                    displayMonth = day.date
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private struct DayInfo {
        let date: Date
        let isInMonth: Bool
        let isToday: Bool
        let weekday: Int
    }

    private func makeDays() -> [DayInfo] {
        let comps = calendar.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        guard let startDate = calendar.date(byAdding: .day, value: -firstWeekday, to: firstOfMonth) else { return [] }
        let today = calendar.startOfDay(for: Date())
        let displayMonthValue = calendar.component(.month, from: firstOfMonth)

        return (0..<42).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate)!
            let inMonth = calendar.component(.month, from: date) == displayMonthValue
            let isToday = calendar.isDate(date, inSameDayAs: today)
            let weekday = calendar.component(.weekday, from: date)
            return DayInfo(date: date, isInMonth: inMonth, isToday: isToday, weekday: weekday)
        }
    }

    private struct DayCell: View {
        let day: DayInfo
        let isSelected: Bool
        let calendar: Calendar
        let onTap: () -> Void

        private var isHoliday: Bool {
            JapaneseHolidays.name(for: day.date) != nil
        }

        var body: some View {
            Button(action: onTap) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(textColor)
                    .frame(width: 26, height: 26)
                    .background(
                        ZStack {
                            if isSelected {
                                Circle().fill(MRTheme.accent)
                            } else if day.isToday {
                                Circle().stroke(MRTheme.accent, lineWidth: 1)
                            }
                        }
                    )
                    .help(JapaneseHolidays.name(for: day.date) ?? "")
            }
            .buttonStyle(.plain)
        }

        private var textColor: Color {
            if isSelected { return .white }
            if !day.isInMonth { return Color.tertiaryText.opacity(0.45) }
            if day.isToday { return MRTheme.accent }
            if day.weekday == 1 || isHoliday {
                return Color(red: 0.86, green: 0.36, blue: 0.36)
            }
            if day.weekday == 7 { return Color(red: 0.36, green: 0.56, blue: 0.86) }
            return Color.primaryText
        }
    }

    private func changeMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayMonth) {
            withAnimation(.easeInOut(duration: 0.18)) {
                displayMonth = next
            }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年 M月"
        return f.string(from: displayMonth)
    }
}

// MARK: - Priority

enum PriorityChoice: Int, CaseIterable, Identifiable {
    case none = 0
    case low = 9
    case medium = 5
    case high = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: return "なし"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

// MARK: - ActionChip

struct ActionChip: View {
    var systemName: String
    var text: String
    var color: Color = .secondaryText
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: text.isEmpty ? 2 : 4) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
            if !text.isEmpty {
                Text(text)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .opacity(0.6)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, text.isEmpty ? 7 : 9)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}
