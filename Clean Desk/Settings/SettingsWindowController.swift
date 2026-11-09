import AppKit
import SwiftUI

/// Hosts the SwiftUI settings form in an AppKit window, so the menu bar app can open it without a scene.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let preferences: Preferences
    private let desktop: DesktopController
    private let updater: AppUpdater
    private let onVisibilityChange: () -> Void
    private var window: NSWindow?

    init(preferences: Preferences, desktop: DesktopController, updater: AppUpdater, onVisibilityChange: @escaping () -> Void) {
        self.preferences = preferences
        self.desktop = desktop
        self.updater = updater
        self.onVisibilityChange = onVisibilityChange
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        // Called from the status menu's action; wait until the menu has finished closing,
        // since activating while menu tracking ends is unreliable.
        DispatchQueue.main.async { [self] in present() }
    }

    private func present() {
        let window = window ?? makeWindow()
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        onVisibilityChange()
        NSApp.activate()
        // Since macOS 14, activate() is only a request that the system can decline for a
        // background app; make sure the window still comes to the front either way.
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        // The window is still "visible" during this callback; re-evaluate once it has gone.
        DispatchQueue.main.async { [self] in onVisibilityChange() }
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView()
            .environment(preferences)
            .environment(desktop)
            .environment(updater)
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: controller)
        window.title = "\(AppInfo.name) Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        // Open on the Space the user is looking at, including over a full-screen app.
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
        window.delegate = self
        return window
    }
}
