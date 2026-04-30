import AppKit
import Carbon
import SwiftUI

struct HotKeyConfiguration: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String

    static let defaultShortcut = HotKeyConfiguration(
        keyCode: 15,
        carbonModifiers: UInt32(optionKey | shiftKey),
        keyLabel: "R"
    )

    var displayText: String {
        modifierDisplay + keyLabel.uppercased()
    }

    private var modifierDisplay: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        return result
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}

final class GlobalHotKeyManager: ObservableObject {
    @Published private(set) var shortcut: HotKeyConfiguration

    var onHotKey: (() -> Void)?
    var onPopoverHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var popoverHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let userDefaultsKey = "globalQuickAddHotKey"
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("RMHK"), id: 1)
    private let popoverHotKeyID = EventHotKeyID(signature: fourCharCode("RMHK"), id: 2)

    // ⌃M: keyCode 46 = "M", controlKey modifier
    private let popoverKeyCode: UInt32 = 46
    private let popoverModifiers: UInt32 = UInt32(controlKey)

    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(HotKeyConfiguration.self, from: data) {
            shortcut = decoded
        } else {
            shortcut = .defaultShortcut
        }

        installEventHandler()
        register()
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func updateShortcut(_ newShortcut: HotKeyConfiguration) {
        shortcut = newShortcut
        if let data = try? JSONEncoder().encode(newShortcut) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        register()
    }

    private func register() {
        unregister()

        // Quick add hotkey
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        }

        // Popover hotkey (⌃M)
        var popRef: EventHotKeyRef?
        let popStatus = RegisterEventHotKey(
            popoverKeyCode,
            popoverModifiers,
            popoverHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &popRef
        )
        if popStatus == noErr {
            popoverHotKeyRef = popRef
        }
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let popoverHotKeyRef {
            UnregisterEventHotKey(popoverHotKeyRef)
            self.popoverHotKeyRef = nil
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var incomingID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &incomingID
                )
                guard status == noErr, incomingID.signature == fourCharCode("RMHK") else {
                    return noErr
                }

                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    switch incomingID.id {
                    case 1: manager.onHotKey?()
                    case 2: manager.onPopoverHotKey?()
                    default: break
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    var onCapture: (HotKeyConfiguration) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class RecorderNSView: NSView {
    var onCapture: ((HotKeyConfiguration) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = HotKeyConfiguration.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            NSSound.beep()
            return
        }
        let label = event.charactersIgnoringModifiers?.uppercased() ?? keyLabel(for: UInt32(event.keyCode))
        onCapture?(
            HotKeyConfiguration(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: modifiers,
                keyLabel: label.isEmpty ? keyLabel(for: UInt32(event.keyCode)) : label
            )
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}

private func keyLabel(for keyCode: UInt32) -> String {
    let labels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        51: "⌫", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
    return labels[keyCode] ?? "Key \(keyCode)"
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.prefix(4).reduce(0) { result, char in
        (result << 8) + OSType(char)
    }
}
