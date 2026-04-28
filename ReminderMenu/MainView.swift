import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

private enum InputMode: String, CaseIterable {
    case normal = "通常"
    case ai = "AI"
}

/// 一覧ビュー / カレンダービューの切替
private enum ListViewMode: String, CaseIterable {
    case list
    case calendar

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }

    var help: String {
        switch self {
        case .list: return "カレンダー表示に切替"
        case .calendar: return "リスト表示に切替"
        }
    }

    func toggled() -> ListViewMode {
        self == .list ? .calendar : .list
    }
}

private struct OptionsPanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@MainActor
final class FnDoubleTapMonitor: ObservableObject {
    private var monitor: Any?
    private var fnDown = false
    private var lastReleaseAt: Date = .distantPast
    private let window: TimeInterval = 0.40
    var onDoubleTap: (() -> Void)?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        // fn key code is 63 on macOS
        guard event.keyCode == 63 else { return }
        let isFn = event.modifierFlags.contains(.function)
        if isFn && !fnDown {
            fnDown = true
        } else if !isFn && fnDown {
            fnDown = false
            let now = Date()
            if now.timeIntervalSince(lastReleaseAt) < window {
                onDoubleTap?()
                lastReleaseAt = .distantPast
            } else {
                lastReleaseAt = now
            }
        }
    }
}

private enum DueChoice: String, CaseIterable, Identifiable {
    case none
    case today
    case tomorrow
    case nextWeek
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "なし"
        case .today: return "今日"
        case .tomorrow: return "明日"
        case .nextWeek: return "来週"
        case .custom: return "選択"
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var store: ReminderStore
    @EnvironmentObject private var app: AppCoordinator
    @EnvironmentObject private var hotKeys: GlobalHotKeyManager
    @EnvironmentObject private var aiSettings: AISettings

    @FocusState private var inputFocused: Bool

    @State private var showListDropdown = false
    @State private var showMoreMenu = false
    @State private var showAISettings = false
    @State private var inputMode: InputMode = .normal
    @State private var listViewMode: ListViewMode = .list
    @StateObject private var fnDoubleTap = FnDoubleTapMonitor()
    @State private var inputText = ""
    @State private var optionsOpen = false
    @State private var dueChoice: DueChoice = .none
    @State private var customDueDate = Date()
    @State private var customIncludesTime = false
    @State private var showCustomDatePopover = false
    @State private var selectedPriority = 0
    @State private var selectedCalendarID: String?
    @State private var inputMemo: String = ""
    @State private var inputNewTag: String = ""
    @State private var inputTags: [String] = []
    @State private var inputFlagged: Bool = false
    @State private var inputURL: String = ""
    @State private var inputRecurrence: RecurrenceFrequency = .none
    @State private var inputEarlyReminder: EarlyReminderChoice = .none
    @State private var showInputDueMenu = false
    @State private var showInputListMenu = false
    @State private var showInputPriorityMenu = false
    @State private var showInputRecurrenceMenu = false
    @State private var showInputAlarmMenu = false
    @State private var optionsPanelHeight: CGFloat = 0
    @State private var isParsing = false
    @State private var showNewListSheet = false
    @State private var showShortcutSheet = false
    @State private var showListManagerSheet = false
    @State private var newListName = ""
    @State private var newListColorIndex = 3

    private var newListColor: Color {
        MRTheme.listColors[min(max(newListColorIndex, 0), MRTheme.listColors.count - 1)]
    }

    private var popoverHeight: CGFloat {
        if showNewListSheet || showShortcutSheet { return 700 }
        let base: CGFloat = 580
        return optionsOpen ? base + max(0, optionsPanelHeight) : base
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            glassBackground

            VStack(spacing: 0) {
                header
                searchBar

                if showListDropdown {
                    listDropdown
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                reminderList

                inputPanel

                if optionsOpen {
                    optionsPanel
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: OptionsPanelHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.top, 10)
            .onPreferenceChange(OptionsPanelHeightKey.self) { newHeight in
                optionsPanelHeight = newHeight
            }

            if let toast = app.toast {
                ToastView(message: toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, optionsOpen ? 172 : 98)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
            }
        }
        .frame(width: 372, height: popoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .preferredColorScheme(app.appearance.colorScheme)
        .onAppear {
            selectedCalendarID = store.selectedCalendarIDForCreation ?? store.calendars.first?.id
            app.requestedPopoverHeight = popoverHeight
            fnDoubleTap.onDoubleTap = { toggleInputMode() }
            fnDoubleTap.start()
        }
        .onDisappear { fnDoubleTap.stop() }
        .background(
            Button(action: toggleInputMode) { EmptyView() }
                .keyboardShortcut("/", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
        .onChange(of: popoverHeight) { _, height in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                app.requestedPopoverHeight = height
            }
        }
        .onChange(of: app.quickAddToken) { _, _ in
            inputMode = .normal
            optionsOpen = app.quickAddShouldOpenOptions
            inputFocused = true
        }
        .onChange(of: inputMode) { _, newMode in
            if newMode == .ai && optionsOpen {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    optionsOpen = false
                }
            }
        }
        .onChange(of: store.selectedCalendarIDForCreation) { _, newValue in
            if let newValue { selectedCalendarID = newValue }
        }
        .sheet(isPresented: $showNewListSheet) {
            newListSheet
                .frame(width: 340)
                .preferredColorScheme(app.appearance.colorScheme)
        }
        .sheet(isPresented: $showAISettings) {
            AISettingsSheet()
                .environmentObject(aiSettings)
                .preferredColorScheme(app.appearance.colorScheme)
        }
        .sheet(isPresented: $showShortcutSheet) {
            shortcutSheet
                .frame(width: 340)
                .preferredColorScheme(app.appearance.colorScheme)
        }
        .sheet(isPresented: $showListManagerSheet) {
            ListManagerSheet()
                .environmentObject(store)
                .environmentObject(app)
                .frame(width: 380)
                .preferredColorScheme(app.appearance.colorScheme)
        }
    }

    private var glassBackground: some View {
        ZStack {
            VisualEffectView(material: .hudWindow)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color.white.opacity(0.62),
                    Color.white.opacity(0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Soft cool highlights for depth (very subtle)
            Circle()
                .fill(Color.white.opacity(0.30))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 110, y: -200)
            Circle()
                .fill(Color(red: 0.92, green: 0.94, blue: 0.97).opacity(0.45))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -130, y: 230)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 0.6)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.88)) {
                    showListDropdown.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(store.selectedColor.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: store.smartListIconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(store.selectedColor)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(store.displayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1)
                        Text(store.displaySubtitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(0.3)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.secondaryText)
                        .rotationEffect(.degrees(showListDropdown ? 180 : 0))
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.04)))
                        .padding(.leading, 1)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(showListDropdown ? "リストを閉じる" : "リストを切り替え")

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    let next = listViewMode.toggled()
                    // カレンダーに切り替えるときは選択を「すべて」に揃える
                    if next == .calendar, store.selectedSmartList != .all {
                        store.selection = .smart(.all)
                    }
                    listViewMode = next
                }
            } label: {
                Image(systemName: listViewMode.toggled().systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(listViewMode == .calendar ? MRTheme.accent : Color.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(listViewMode.help)

            Button {
                store.showCompleted.toggle()
            } label: {
                Image(systemName: store.showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(store.showCompleted ? MRTheme.accent : Color.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help(store.showCompleted ? "完了済みを非表示" : "完了済みを表示")

            Button {
                showMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMoreMenu, arrowEdge: .top) {
                moreMenuContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)
            TextField("検索", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.tertiaryText)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var listDropdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SmartList.allCases) { smart in
                    SmartListTile(
                        smartList: smart,
                        count: store.count(for: smart),
                        isSelected: store.selection == .smart(smart)
                    ) {
                        select(.smart(smart))
                    }
                }
            }

            Text("マイリスト")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.tertiaryText)
                .tracking(0.8)
                .padding(.horizontal, 4)

            FlowLayout(spacing: 6) {
                ForEach(store.calendars) { calendar in
                    DropTargetCalendarChip(calendar: calendar, onSelect: {
                        select(.calendar(calendar.id))
                    })
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    /// カレンダー表示は「すべて」スマートリスト + ユーザーが切替モード ON のときだけ有効
    private var showCalendar: Bool {
        listViewMode == .calendar && store.selectedSmartList == .all
    }

    /// グループ内のリマインダーを「親 → 子」の順に並べ、各要素にインデント深さを付与する。
    /// 親が同じグループに居ない子は depth=0 でフォールバック表示するが、
    /// `isOrphanedChild=true` を付けて UI 側で「子タスク」マークを出せるようにする。
    private func buildReminderTree(_ items: [EKReminder]) -> [ReminderTreeNode] {
        let allIDs = Set(items.map(\.calendarItemIdentifier))
        let parentMap = store.parentMap

        var childrenByParent: [String: [EKReminder]] = [:]
        var topLevel: [(EKReminder, Bool)] = []  // (reminder, isOrphanedChild)
        for item in items {
            if let parentID = parentMap[item.calendarItemIdentifier] {
                if allIDs.contains(parentID) {
                    childrenByParent[parentID, default: []].append(item)
                } else {
                    topLevel.append((item, true))
                }
            } else {
                topLevel.append((item, false))
            }
        }

        var nodes: [ReminderTreeNode] = []
        nodes.reserveCapacity(items.count)
        for (parent, isOrphan) in topLevel {
            nodes.append(ReminderTreeNode(reminder: parent, depth: 0, isOrphanedChild: isOrphan))
            for child in childrenByParent[parent.calendarItemIdentifier] ?? [] {
                nodes.append(ReminderTreeNode(reminder: child, depth: 1, isOrphanedChild: false))
            }
        }
        return nodes
    }

    private var fullDiskAccessBanner: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text("サブタスクの階層表示にはフルディスクアクセスが必要です")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("クリックして設定を開く → Nudge を ON にしてアプリを再起動")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    private var reminderList: some View {
        Group {
            if !store.hasFullAccess {
                permissionView
            } else if store.filteredReminders.isEmpty && !showCalendar {
                emptyView
            } else if showCalendar {
                CalendarView(reminders: store.filteredReminders)
                    .environmentObject(store)
            } else {
                VStack(spacing: 0) {
                    if !store.hasFullDiskAccess {
                        fullDiskAccessBanner
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(store.groupedReminders, id: \.id) { group in
                                if let title = group.title {
                                    HStack(spacing: 7) {
                                        Rectangle()
                                            .fill(group.color)
                                            .frame(width: 7, height: 7)
                                            .rotationEffect(.degrees(45))
                                        Text(title)
                                            .font(.system(size: 10.5, weight: .bold))
                                            .foregroundStyle(Color.secondaryText)
                                            .tracking(0.4)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                                }

                                ForEach(buildReminderTree(group.reminders), id: \.id) { node in
                                    ReminderRow(
                                        reminder: node.reminder,
                                        indentLevel: node.depth,
                                        isOrphanedChild: node.isOrphanedChild
                                    )
                                        .padding(.horizontal, 8)
                                        .transition(
                                            .asymmetric(
                                                insertion: .opacity
                                                    .combined(with: .scale(scale: 0.7, anchor: .top))
                                                    .combined(with: .offset(y: -40)),
                                                removal: .opacity.combined(with: .move(edge: .leading))
                                            )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: store.reminders.map(\.calendarItemIdentifier))
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(MRTheme.accent)
            Text("リマインダーへのアクセスが必要です")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.primaryText)
            Button("アクセスを許可") {
                store.requestAccessAndLoad()
            }
            .buttonStyle(.borderedProminent)
            .tint(MRTheme.accent)
        }
        .padding(24)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MRTheme.accent)
            Text("表示するリマインダーはありません")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(24)
    }

    private var aiToggleButton: some View {
        let isAI = inputMode == .ai
        return Menu {
            Button(isAI ? "通常モードに戻す" : "AI モードに切替") {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                    inputMode = isAI ? .normal : .ai
                }
            }
            Divider()
            Section("AI プロバイダ") {
                ForEach(AIProviderID.allCases) { provider in
                    Button {
                        aiSettings.providerID = provider
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                            inputMode = .ai
                        }
                    } label: {
                        HStack {
                            Text(provider.displayName)
                            if aiSettings.providerID == provider {
                                Image(systemName: "checkmark")
                            }
                            if provider.requiresAPIKey && !aiSettings.hasAPIKey(provider) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Divider()
            Button("AI 設定を開く…") { showAISettings = true }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isAI ? Color.white : Color.secondaryText)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(isAI ? AnyShapeStyle(MRTheme.accent) : AnyShapeStyle(Color.black.opacity(0.05)))
                )
                .overlay(
                    Circle().stroke(
                        isAI ? MRTheme.accent.opacity(0.7) : Color.black.opacity(0.1),
                        lineWidth: isAI ? 0.8 : 0.5
                    )
                )
                .shadow(color: isAI ? MRTheme.accent.opacity(0.35) : .clear, radius: 6, y: 2)
        } primaryAction: {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                inputMode = isAI ? .normal : .ai
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(isAI
              ? "AI モード（\(aiSettings.providerID.displayName)）— 長押しでプロバイダ切替"
              : "通常モード — 長押しで AI プロバイダ切替")
    }


    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                aiToggleButton

                TextField(
                    inputMode == .ai ? "自然言語で追加…" : "新規リマインダー…",
                    text: $inputText,
                    axis: .vertical
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .lineLimit(1...8)
                    .focused($inputFocused)
                    .disabled(isParsing)
                    .onKeyPress(.return) {
                        // Shift+Return は改行を許可
                        if NSEvent.modifierFlags.contains(.shift) {
                            return .ignored
                        }
                        // IME 変換中（marked text あり）なら確定の Enter として通す
                        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
                           editor.hasMarkedText() {
                            return .ignored
                        }
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
                            .background(Color.black.opacity(0.04), in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help(optionsOpen ? "オプションを閉じる" : "オプションを開く")
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
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(inputMode == .ai ? MRTheme.accent.opacity(0.55) : Color.black.opacity(0.08), lineWidth: 0.6)
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            inputMemoField
            inputTagSection
            inputURLField
            inputActionRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
    }

    private var inputURLField: some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.tertiaryText)

            TextField("URL", text: $inputURL)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primaryText)
        }
    }

    private var inputMemoField: some View {
        TextField("メモ", text: $inputMemo, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .foregroundStyle(Color.primaryText)
            .lineLimit(1...4)
    }

    private var inputTagSection: some View {
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
    }

    private var inputActionRow: some View {
        HStack(spacing: 4) {
            inputDueChip
            if dueChoice != .none {
                Button {
                    dueChoice = .none
                    customIncludesTime = false
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
            inputPriorityChip
            inputRecurrenceChip
            inputAlarmChip
            inputFlagToggleChip
            Spacer(minLength: 0)
            inputListChip
        }
    }

    private var inputRecurrenceChip: some View {
        Button {
            showInputRecurrenceMenu = true
        } label: {
            ActionChip(
                systemName: "arrow.triangle.2.circlepath",
                text: inputRecurrence == .none ? "" : inputRecurrence.label,
                color: inputRecurrence != .none ? MRTheme.accent : .secondaryText
            )
        }
        .buttonStyle(.plain)
        .help("繰り返し")
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

    private var inputAlarmChip: some View {
        Button {
            showInputAlarmMenu = true
        } label: {
            ActionChip(
                systemName: "bell",
                text: inputEarlyReminder == .none ? "" : inputEarlyReminder.shortLabel,
                color: inputEarlyReminder != .none ? MRTheme.accent : .secondaryText
            )
        }
        .buttonStyle(.plain)
        .help("通知")
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

    // MARK: - Input chips

    private var inputDueChip: some View {
        Button {
            showInputDueMenu = true
        } label: {
            ActionChip(
                systemName: "calendar",
                text: inputDueChipLabel,
                color: dueChoice != .none ? MRTheme.accent : .secondaryText,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showInputDueMenu, arrowEdge: .top) {
            inputDueMenu
        }
    }

    private var inputDueChipLabel: String {
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

    private var inputDueMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            ModernMenuTitle(label: "期限")
            ModernMenuRow(icon: "minus.circle", label: "なし", trailingChecked: dueChoice == .none) {
                dueChoice = .none
                showInputDueMenu = false
            }
            ModernMenuRow(icon: "sun.max", label: "今日", trailingChecked: dueChoice == .today) {
                dueChoice = .today
                showInputDueMenu = false
            }
            ModernMenuRow(icon: "sunrise", label: "明日", trailingChecked: dueChoice == .tomorrow) {
                dueChoice = .tomorrow
                showInputDueMenu = false
            }
            ModernMenuRow(icon: "calendar.badge.clock", label: "来週", trailingChecked: dueChoice == .nextWeek) {
                dueChoice = .nextWeek
                showInputDueMenu = false
            }

            ModernMenuDivider()

            ModernCalendar(selection: Binding(
                get: { customDueDate },
                set: {
                    customDueDate = $0
                    dueChoice = .custom
                }
            ))

            Toggle("時刻を含める", isOn: $customIncludesTime.animation())
                .font(.system(size: 10.5, weight: .semibold))
                .toggleStyle(.switch)
                .tint(MRTheme.accent)
                .controlSize(.mini)

            if customIncludesTime {
                ModernTimePicker(date: $customDueDate)
            }

            HStack {
                Spacer()
                Button("完了") { showInputDueMenu = false }
                    .buttonStyle(.borderedProminent)
                    .tint(MRTheme.accent)
                    .controlSize(.mini)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 270)
    }

    private var inputPriorityChip: some View {
        Button {
            showInputPriorityMenu = true
        } label: {
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

    private var inputFlagToggleChip: some View {
        Button {
            inputFlagged.toggle()
        } label: {
            Image(systemName: inputFlagged ? "flag.fill" : "flag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(inputFlagged ? MRTheme.accent : Color.tertiaryText)
                .frame(width: 26, height: 22)
                .background(inputFlagged ? MRTheme.accentSoft : Color.black.opacity(0.04), in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(inputFlagged ? "フラグを外す" : "フラグを付ける")
    }

    private var inputListChip: some View {
        let id = selectedCalendarID ?? store.calendars.first?.id ?? ""
        let cal = store.calendars.first(where: { $0.id == id })
        return Button {
            showInputListMenu = true
        } label: {
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
            .background(Color.white.opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.10), lineWidth: 0.5))
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

    // MARK: - More menu (header "..." popover)

    private var moreMenuContent: some View {
        ModernMenuSurface {
            VStack(alignment: .leading, spacing: 1) {
                ModernMenuRow(icon: "plus", label: "新規リマインダー") {
                    showMoreMenu = false
                    optionsOpen = true
                    inputFocused = true
                }
                ModernMenuRow(icon: "folder.badge.plus", label: "新規リスト作成") {
                    showMoreMenu = false
                    showNewListSheet = true
                }
                ModernMenuRow(icon: "list.bullet.rectangle", label: "リストを管理") {
                    showMoreMenu = false
                    showListManagerSheet = true
                }

                ModernMenuDivider()

                ModernMenuToggleRow(
                    icon: "checkmark.circle",
                    label: "完了済みを表示",
                    isOn: $store.showCompleted
                )
                ModernMenuRow(
                    icon: "trash",
                    label: "完了済みを削除",
                    destructive: true
                ) {
                    showMoreMenu = false
                    store.deleteCompleted()
                }

                ModernMenuDivider()

                ModernMenuSectionHeader(label: "並び替え")
                ModernSegmented(
                    values: SortMode.allCases.map { ($0, $0.title) },
                    selection: $store.sortMode
                )
                .padding(.bottom, 4)

                ModernMenuSectionHeader(label: "外観")
                ModernSegmented(
                    values: AppearanceMode.allCases.map { ($0, $0.title) },
                    selection: $app.appearance
                )
                .padding(.bottom, 4)

                ModernMenuRow(icon: "keyboard", label: "ショートカット設定") {
                    showMoreMenu = false
                    showShortcutSheet = true
                }
                ModernMenuRow(icon: "sparkles", label: "AI 設定") {
                    showMoreMenu = false
                    showAISettings = true
                }

                ModernMenuDivider()

                ModernMenuRow(icon: "arrow.clockwise", label: "再読み込み") {
                    showMoreMenu = false
                    store.reloadAll()
                }
                ModernMenuRow(icon: "arrow.up.forward.app", label: "リマインダーアプリを開く") {
                    showMoreMenu = false
                    store.openRemindersApp()
                }
            }
        }
        .frame(width: 260)
        .padding(6)
    }

    private var newListSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新しいリスト")
                .font(.system(size: 17, weight: .bold))

            HStack(spacing: 10) {
                Circle()
                    .fill(newListColor)
                    .frame(width: 16, height: 16)
                TextField("リスト名", text: $newListName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MRTheme.accent.opacity(0.45), lineWidth: 1))

            HStack(spacing: 10) {
                ForEach(Array(MRTheme.listColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        newListColorIndex = index
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(.primary.opacity(newListColorIndex == index ? 0.8 : 0), lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button("作成") {
                    do {
                        let id = try store.createList(name: newListName, color: newListColor)
                        store.selection = .calendar(id)
                        selectedCalendarID = id
                        app.showToast(ToastMessage(kind: .success, title: "リストを作成しました", detail: newListName))
                        newListName = ""
                        showNewListSheet = false
                    } catch {
                        app.showToast(ToastMessage(kind: .failure, title: "リストを作成できませんでした", detail: error.localizedDescription))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MRTheme.accent)
                .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("キャンセル") {
                    showNewListSheet = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }

    private var shortcutSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ショートカット")
                .font(.system(size: 17, weight: .bold))
            Text("現在: \(hotKeys.shortcut.displayText)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondaryText)

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MRTheme.accent.opacity(0.45), lineWidth: 1))
                VStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MRTheme.accent)
                    Text("登録したいキーを押す")
                        .font(.system(size: 13, weight: .semibold))
                }
                ShortcutRecorder { shortcut in
                    hotKeys.updateShortcut(shortcut)
                    app.showToast(ToastMessage(kind: .success, title: "ショートカットを登録しました", detail: shortcut.displayText))
                }
            }
            .frame(height: 120)

            HStack {
                Button("デフォルトに戻す") {
                    hotKeys.updateShortcut(.defaultShortcut)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") {
                    showShortcutSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(MRTheme.accent)
            }
        }
        .padding(20)
    }

    private func select(_ selection: ReminderSelection) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            store.selection = selection
            showListDropdown = false
        }
    }

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
                if !memoText.isEmpty {
                    store.setMemo(created, memo: memoText)
                }
                for tag in inputTags {
                    store.addTag(tag, to: created)
                }
                if inputFlagged {
                    store.toggleFlagged(created)
                }
                let urlText = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !urlText.isEmpty, let url = URL(string: urlText) {
                    store.setURL(created, url: url)
                }
                if inputRecurrence != .none {
                    store.setRecurrence(created, frequency: inputRecurrence)
                }
                if inputEarlyReminder != .none {
                    store.setEarlyReminder(created, choice: inputEarlyReminder)
                }
                app.showAddedToast(titles: [text])
                resetInput()
            } catch {
                app.showToast(ToastMessage(kind: .failure, title: "追加できませんでした", detail: error.localizedDescription))
            }
        } else {
            Task { @MainActor in
                isParsing = true
                let drafts = await NLParser.parse(text, availableLists: store.calendars, using: aiSettings.currentProvider())
                do {
                    guard !drafts.isEmpty else {
                        app.showToast(ToastMessage(kind: .failure, title: "タスクを読み取れませんでした", detail: nil))
                        isParsing = false
                        return
                    }
                    let titles = try store.addDrafts(drafts, fallbackCalendarID: selectedCalendarID ?? store.selectedCalendarIDForCreation)
                    app.showAddedToast(titles: titles)
                    resetInput()
                } catch {
                    app.showToast(ToastMessage(kind: .failure, title: "追加できませんでした", detail: error.localizedDescription))
                }
                isParsing = false
            }
        }
    }

    private func selectedDueDate() -> (date: Date?, includesTime: Bool) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch dueChoice {
        case .none:
            return (nil, false)
        case .today:
            return (today, false)
        case .tomorrow:
            return (calendar.date(byAdding: .day, value: 1, to: today), false)
        case .nextWeek:
            return (calendar.date(byAdding: .day, value: 7, to: today), false)
        case .custom:
            return (customDueDate, customIncludesTime)
        }
    }

    private func resetInput() {
        inputText = ""
        inputMemo = ""
        inputNewTag = ""
        inputTags = []
        inputFlagged = false
        inputURL = ""
        inputRecurrence = .none
        inputEarlyReminder = .none
        dueChoice = .none
        customIncludesTime = false
        selectedPriority = 0
        optionsOpen = false
    }

    private func toggleInputMode() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            inputMode = inputMode == .ai ? .normal : .ai
        }
        inputFocused = true
    }
}

struct DropTargetCalendarChip: View {
    @EnvironmentObject private var store: ReminderStore
    let calendar: ReminderCalendar
    let onSelect: () -> Void
    @State private var isTargeted: Bool = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Circle()
                    .fill(calendar.color)
                    .frame(width: 7, height: 7)
                Text(calendar.title)
                    .lineLimit(1)
                Text("\(calendar.count)")
                    .foregroundStyle(Color.tertiaryText)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(Color.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isTargeted
                    ? AnyShapeStyle(calendar.color.opacity(0.25))
                    : AnyShapeStyle(.ultraThinMaterial),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isTargeted ? calendar.color : Color.white.opacity(0.38),
                    lineWidth: isTargeted ? 1.5 : 0.5
                )
            )
            .scaleEffect(isTargeted ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let identifier = item as? String else { return }
            DispatchQueue.main.async {
                store.moveReminder(identifier: identifier, toCalendarID: calendar.id)
            }
        }
        return true
    }
}

private struct SmartListTile: View {
    var smartList: SmartList
    var count: Int
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: smartList.symbolName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 25, height: 25)
                        .background(isSelected ? Color.white.opacity(0.22) : smartList.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 19, weight: .bold))
                        .monospacedDigit()
                }
                Text(smartList.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primaryText)
            .padding(12)
            .background(tileBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.42), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var tileBackground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [smartList.color, smartList.color.opacity(0.76)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color.white.opacity(0.28))
    }
}

private struct OptionSection<Content: View>: View {
    var title: String
    var content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.tertiaryText)
                .tracking(0.6)
            content()
        }
    }
}

private struct OptionChip: View {
    var title: String
    var systemName: String?
    var isActive: Bool
    var activeColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isActive ? Color.white : Color.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? activeColor : Color.black.opacity(0.04), in: Capsule())
            .overlay(Capsule().stroke(isActive ? Color.clear : Color.black.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct ToastView: View {
    var message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(1)
                if let detail = message.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(.white.opacity(0.46), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    private var icon: String {
        switch message.kind {
        case .success: return "checkmark"
        case .failure: return "exclamationmark"
        case .info: return "info"
        }
    }

    private var iconColor: Color {
        switch message.kind {
        case .success: return MRTheme.green
        case .failure: return MRTheme.red
        case .info: return MRTheme.accent
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let rows = rows(for: subviews, width: width)
        return CGSize(width: width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> (height: CGFloat, count: Int) {
        var x: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0
        var count = 1

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
                count += 1
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        height += rowHeight
        return (height, count)
    }
}
