import AppKit
import SwiftUI

/// Raycast 風フローティングパネルのライフサイクルを管理する。
/// ホットキー押下 → toggle() で表示 / 非表示。
@MainActor
final class QuickAddWindowController {
    private var panel: QuickAddPanel?
    private let store: ReminderStore
    private let app: AppCoordinator
    private let aiSettings: AISettings

    init(store: ReminderStore, app: AppCoordinator, aiSettings: AISettings) {
        self.store = store
        self.app = app
        self.aiSettings = aiSettings
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { close() } else { show() }
    }

    func show() {
        if panel == nil { makePanel() }
        guard let panel else { return }

        positionPanel(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    // MARK: - Private

    private func makePanel() {
        let panel = QuickAddPanel(
            contentRect: NSRect(x: 0, y: 0, width: 584, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onClose = { [weak self] in self?.close() }

        let host = NSHostingController(
            rootView: QuickAddView(onDismiss: { [weak self] in self?.close() })
                .environmentObject(store)
                .environmentObject(app)
                .environmentObject(aiSettings)
        )
        host.view.frame = panel.contentRect(forFrameRect: panel.frame)
        host.view.autoresizingMask = [.width, .height]
        panel.contentView = host.view

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 584
        let x = visibleFrame.origin.x + (visibleFrame.width - panelWidth) / 2
        let y = visibleFrame.origin.y + visibleFrame.height * 0.72
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// borderless + floating の NSPanel。ESC でクローズ、key ウィンドウになれる。
final class QuickAddPanel: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }
}
