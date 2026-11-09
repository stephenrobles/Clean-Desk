import AppKit
import KeyboardShortcuts

@main
enum CleanDeskApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    lazy var desktop = DesktopController(preferences: preferences)
    let updater = AppUpdater()
    private var statusItemController: StatusItemController?
    private lazy var settingsWindowController = SettingsWindowController(
        preferences: preferences, desktop: desktop, updater: updater,
        onVisibilityChange: { [weak self] in self?.applyActivationPolicy() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        statusItemController = StatusItemController(desktop: desktop, updater: updater) { [weak self] in
            self?.showSettings()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleDesktop) { [weak self] in
            self?.desktop.toggle()
        }
        applyActivationPolicy()
        observeDockPreference()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    /// `cleandesk://hide`, `cleandesk://show`, `cleandesk://toggle` and `cleandesk://settings`, for Shortcuts,
    /// launchers and scripts.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme?.lowercased() == "cleandesk" {
            switch url.host()?.lowercased() {
            case "hide": desktop.hide()
            case "show": desktop.show()
            case "toggle": desktop.toggle()
            case "settings": showSettings()
            default: break
            }
        }
    }

    /// Quitting the app brings the desktop back, so nobody is left with hidden files and no menu bar icon
    /// to recover them. Logging out, restarting or shutting down leaves the desktop as it is: Finder is going
    /// away anyway, and the hidden state is restored on the next launch at login.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if desktop.isDesktopHidden, !isSystemInitiatedQuit {
            desktop.show()
        }
        return .terminateNow
    }

    private var isSystemInitiatedQuit: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              let reason = event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.enumCodeValue else {
            return false
        }
        let systemReasons: [OSType] = [
            OSType(kAELogOut), OSType(kAEReallyLogOut),
            OSType(kAEShowRestartDialog), OSType(kAEShowShutdownDialog),
            OSType(kAERestart), OSType(kAEShutDown),
        ]
        return systemReasons.contains(reason)
    }

    @objc func showSettings() {
        settingsWindowController.show()
    }

    @objc func checkForUpdates() {
        updater.checkForUpdates()
    }

    @objc func toggleDesktop() {
        desktop.toggle()
    }

    /// The app shows in the Dock when the user asks for it, and while Settings is open so the window
    /// behaves like a normal app window; otherwise it lives only in the menu bar.
    private func applyActivationPolicy() {
        let wantsDock = preferences.showDockIcon || settingsWindowController.isVisible
        let policy: NSApplication.ActivationPolicy = wantsDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
    }

    private func observeDockPreference() {
        withObservationTracking {
            _ = preferences.showDockIcon
        } onChange: {
            Task { @MainActor [weak self] in
                self?.applyActivationPolicy()
                self?.observeDockPreference()
            }
        }
    }

    /// Only visible while the Settings window is open, but provides standard editing shortcuts.
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(AppInfo.name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        if AppUpdater.isAvailable {
            appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(AppInfo.name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu

        let desktopMenu = NSMenu(title: "Desktop")
        let toggle = desktopMenu.addItem(withTitle: "Toggle Desktop Icons", action: #selector(toggleDesktop), keyEquivalent: "")
        toggle.target = self
        toggle.setShortcut(for: .toggleDesktop)
        mainMenu.addItem(withTitle: "Desktop", action: nil, keyEquivalent: "").submenu = desktopMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }
}
