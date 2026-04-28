import SwiftUI

// MARK: - Surface

struct ModernMenuSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(MRTheme.Surface.glass)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MRTheme.Border.hairline, lineWidth: 0.5)
            )
            .shadow(color: MRTheme.Border.line, radius: 18, y: 8)
    }
}

// MARK: - Row

struct ModernMenuRow: View {
    var icon: String?
    var iconColor: Color = .secondaryText
    var leadingDot: Color? = nil
    var label: String
    var trailingChecked: Bool = false
    var destructive: Bool = false
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leadingDot {
                    Circle()
                        .fill(leadingDot)
                        .frame(width: 7, height: 7)
                        .frame(width: 14, alignment: .leading)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(destructive ? MRTheme.red : iconColor)
                        .frame(width: 14, alignment: .leading)
                }
                Text(label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(destructive ? MRTheme.red : Color.primaryText)
                Spacer(minLength: 10)
                if trailingChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(MRTheme.accent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? MRTheme.Border.hairline : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Toggle row

struct ModernMenuToggleRow: View {
    var icon: String?
    var label: String
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 14, alignment: .leading)
            }
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.primaryText)
            Spacer(minLength: 10)
            MRModernSwitch(isOn: $isOn, compact: true)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? MRTheme.Border.hairline : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { isOn.toggle() }
    }
}

// MARK: - Section header

struct ModernMenuSectionHeader: View {
    var label: String
    var body: some View {
        Text(label)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Color.tertiaryText)
            .tracking(0.6)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Menu title header (top of popover)

struct ModernMenuTitle: View {
    var label: String
    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 6)
            Rectangle()
                .fill(MRTheme.Border.hairline)
                .frame(height: 0.5)
                .padding(.horizontal, 6)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Inline segmented selector

struct ModernSegmented<Value: Hashable>: View {
    var values: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(values, id: \.0) { value, label in
                Button {
                    if selection != value {
                        selection = value
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selection == value ? Color.white : Color.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == value ? AnyShapeStyle(MRTheme.accent) : AnyShapeStyle(MRTheme.Surface.inset),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
    }
}

// MARK: - Divider

struct ModernMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(MRTheme.Border.hairline)
            .frame(height: 0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }
}

// MARK: - Modern time picker (hour:minute fields + presets)

struct ModernTimePicker: View {
    @Binding var date: Date

    private static let presets: [(Int, Int, String)] = [
        (9, 0, "9:00"),
        (12, 0, "12:00"),
        (15, 0, "15:00"),
        (18, 0, "18:00"),
        (21, 0, "21:00")
    ]

    private var hour: Int { Calendar.current.component(.hour, from: date) }
    private var minute: Int { Calendar.current.component(.minute, from: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                TimeNumberField(
                    value: hour,
                    range: 0...23,
                    width: 36
                ) { setHour($0) }
                Text(":")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.secondaryText)
                TimeNumberField(
                    value: minute,
                    range: 0...59,
                    width: 36
                ) { setMinute($0) }

                Spacer(minLength: 6)

                Stepper("", onIncrement: { addMinutes(15) }, onDecrement: { addMinutes(-15) })
                    .labelsHidden()
                    .controlSize(.mini)
            }

            HStack(spacing: 4) {
                ForEach(Self.presets, id: \.2) { h, m, label in
                    Button {
                        setTime(hour: h, minute: m)
                    } label: {
                        Text(label)
                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(isSelected(h: h, m: m) ? .white : Color.primaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                isSelected(h: h, m: m)
                                    ? AnyShapeStyle(MRTheme.accent)
                                    : AnyShapeStyle(MRTheme.Surface.inset),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func isSelected(h: Int, m: Int) -> Bool {
        hour == h && minute == m
    }

    private func setHour(_ h: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.hour = h
        if let next = cal.date(from: comps) { date = next }
    }

    private func setMinute(_ m: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.minute = m
        if let next = cal.date(from: comps) { date = next }
    }

    private func setTime(hour h: Int, minute m: Int) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.hour = h
        comps.minute = m
        if let next = cal.date(from: comps) { date = next }
    }

    private func addMinutes(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .minute, value: delta, to: date) {
            date = next
        }
    }
}

private struct TimeNumberField: View {
    let value: Int
    let range: ClosedRange<Int>
    let width: CGFloat
    let onCommit: (Int) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
            .foregroundStyle(Color.primaryText)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 4)
            .background(MRTheme.Surface.field, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(focused ? MRTheme.accent : MRTheme.Border.line, lineWidth: focused ? 1.2 : 0.5)
            )
            .focused($focused)
            .onAppear { text = String(format: "%02d", value) }
            .onChange(of: value) { _, newValue in
                if !focused { text = String(format: "%02d", newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onSubmit { commit(); focused = false }
    }

    private func commit() {
        let digits = text.filter(\.isNumber)
        let parsed = Int(digits) ?? value
        let clamped = max(range.lowerBound, min(range.upperBound, parsed))
        onCommit(clamped)
        text = String(format: "%02d", clamped)
    }
}

// MARK: - List picker (calendar/list selector)

struct ListPicker: View {
    let calendars: [ReminderCalendar]
    @Binding var selectedID: String

    @State private var isOpen = false

    private var selected: ReminderCalendar? {
        calendars.first(where: { $0.id == selectedID })
    }

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 8) {
                if let s = selected {
                    Circle().fill(s.color).frame(width: 8, height: 8)
                    Text(s.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.primaryText)
                } else {
                    Text("リストを選択")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(MRTheme.Surface.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MRTheme.Border.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            ModernMenuSurface {
                VStack(spacing: 1) {
                    ModernMenuTitle(label: "リスト")
                    ForEach(calendars) { calendar in
                        ModernMenuRow(
                            leadingDot: calendar.color,
                            label: calendar.title,
                            trailingChecked: calendar.id == selectedID
                        ) {
                            selectedID = calendar.id
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
