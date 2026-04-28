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
        let image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "ReminderMenu")
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.title = ""
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 372, height: 540)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MainView()
                .environmentObject(reminderStore)
                .environmentObject(appCoordinator)
                .environmentObject(hotKeyManager)
                .environmentObject(aiSettings)
        )

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
