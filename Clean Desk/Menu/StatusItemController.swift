import AppKit
import KeyboardShortcuts

/// The menu bar icon and its menu. The icon reflects whether the desktop is currently hidden.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let desktop: DesktopController
    private let updater: AppUpdater
    private let showSettings: () -> Void
    private let toggleItem = NSMenuItem()

    init(desktop: DesktopController, updater: AppUpdater, showSettings: @escaping () -> Void) {
        self.desktop = desktop
        self.updater = updater
        self.showSettings = showSettings
        super.init()

        let menu = NSMenu()
        menu.delegate = self

        toggleItem.action = #selector(toggle)
        toggleItem.target = self
        toggleItem.setShortcut(for: .toggleDesktop)
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        if AppUpdater.isAvailable {
            menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.toolTip = AppInfo.name
        update()
        observeState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        update()
    }

    private func update() {
        let hidden = desktop.isDesktopHidden
        toggleItem.title = hidden ? "Show Desktop Icons" : "Hide Desktop Icons"
        let symbol = hidden ? "sparkles" : "rectangle.grid.2x2"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: hidden ? "Desktop hidden" : "Desktop shown")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func observeState() {
        withObservationTracking {
            _ = desktop.isDesktopHidden
        } onChange: {
            Task { @MainActor [weak self] in
                self?.update()
                self?.observeState()
            }
        }
    }

    @objc private func toggle() {
        desktop.toggle()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }
}
