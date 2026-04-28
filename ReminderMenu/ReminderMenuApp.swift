import AppKit
import Combine
import SwiftUI

@main
struct ReminderMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let reminderStore = ReminderStore()
    private let appCoordinator = AppCoordinator()
    private let hotKeyManager = GlobalHotKeyManager()
    private let aiSettings = AISettings()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()

        appCoordinator.showPopover = { [weak self] in
            self?.showPopover()
        }
        hotKeyManager.onHotKey = { [weak appCoordinator] in
            appCoordinator?.showQuickAdd(openOptions: false)
        }

        // メニューバーアイコンの脈動アニメを ReminderStore のパルスにフック
        reminderStore.menuBarPulses
            .receive(on: RunLoop.main)
            .sink { [weak self] pulse in
                self?.pulseStatusButton(for: pulse)
            }
            .store(in: &cancellables)

        // 外観切替を NSApp 全体に反映（NSPopover 内のサブメニューも同時切替するため）
        appCoordinator.$appearance
            .receive(on: RunLoop.main)
            .sink { mode in
                NSApp.appearance = mode.nsAppearance
            }
            .store(in: &cancellables)
        // 起動時の初期反映
        NSApp.appearance = appCoordinator.appearance.nsAppearance

        reminderStore.requestAccessAndLoad()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancellables.removeAll()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Hutch")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.action = #selector(togglePopover)
        button.target = self
        // 脈動アニメ用にレイヤーバック
        button.wantsLayer = true
    }

    /// メニューバーアイコンを 3 回ほど大小させる脈動アニメ。
    /// 通知が来たことを「動き」だけで伝える。ポップオーバー表示中は省略
    /// （既に確認動作中なので、追加で動かすと過剰）。
    private func pulseStatusButton(for pulse: MenuBarPulse) {
        guard let button = statusItem.button, !popover.isShown else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }

        // anchor を中心に固定（NSStatusItem.button のデフォルトは左下なので scale で位置がずれる）
        let center = CGPoint(x: layer.bounds.midX, y: layer.bounds.midY)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = center

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.22
        scale.duration = 0.32
        scale.autoreverses = true
        scale.repeatCount = 3
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(scale, forKey: "pulse")

        // 鐘マークに一時的に切替（脈動が終わるまで＝約 1.92 秒）
        let original = button.image
        let bell = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "Notification")
        bell?.isTemplate = true
        button.image = bell
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) { [weak self] in
            // 別パルスで上書きされていなければ元に戻す
            guard let self, let btn = self.statusItem.button else { return }
            if btn.image == bell {
                btn.image = original
            }
        }
        _ = pulse  // 現状はパルスの種類で挙動を変えていない（将来的に kind で色や音を分岐可能）
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 372, height: 540)
        popover.delegate = self
        let host = NSHostingController(
            rootView: MainView()
                .environmentObject(reminderStore)
                .environmentObject(appCoordinator)
                .environmentObject(hotKeyManager)
                .environmentObject(aiSettings)
        )
        // SwiftUI 側のクリップ（22px）と NSPopover のフレームが重なる際に
        // 角の隙間から NSPopover 地が見える問題を防ぐため、ホスト View も
        // レイヤーで丸角クリップを掛けて完全に揃える。
        host.view.wantsLayer = true
        host.view.layer?.cornerRadius = 14
        host.view.layer?.cornerCurve = .continuous
        host.view.layer?.masksToBounds = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = host

        appCoordinator.$requestedPopoverHeight
            .receive(on: RunLoop.main)
            .sink { [weak popover] height in
                popover?.contentSize = NSSize(width: 372, height: height)
            }
            .store(in: &cancellables)
    }

    private func updateStatusCount() {
        let count = reminderStore.count(for: .today)
        statusItem.button?.title = " \(count)"
    }
}
