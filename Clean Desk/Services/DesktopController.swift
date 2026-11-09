import AppKit
import Observation
import os

/// Hides and shows everything on the desktop (files, folders, mounted disks).
///
/// The direct-download build turns off Finder's desktop, the same switch as
/// `defaults write com.apple.finder CreateDesktop false`. Finder only reads it at launch, so it is
/// relaunched after each change; launchd brings it straight back. The App Store build is sandboxed
/// and can't do either, so it covers the icons with a window instead (see `DesktopCover`).
@Observable
final class DesktopController {
    private(set) var isDesktopHidden: Bool
    private(set) var lastError: String?

    @ObservationIgnored private let log = Logger(subsystem: "fm.beard.CleanDesk", category: "desktop")

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    #if APPSTORE
    @ObservationIgnored private let cover: DesktopCover
    #else
    @ObservationIgnored private let wallpaper: WallpaperController
    #endif

    init(preferences: Preferences) {
        self.preferences = preferences
        #if APPSTORE
        cover = DesktopCover(preferences: preferences)
        isDesktopHidden = false
        if preferences.coverActive { hide() }
        #else
        wallpaper = WallpaperController(preferences: preferences)
        // The Finder setting outlives the app, so a relaunch (say, at login) picks up the real state.
        isDesktopHidden = !Self.finderCreatesDesktop()
        #endif

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // A display plugged in while hidden should be covered, or get the custom wallpaper, too.
            MainActor.assumeIsolated { self?.displaysChanged() }
        })
        #if APPSTORE
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Each Space can have its own wallpaper; redraw the cover for the one now showing.
            MainActor.assumeIsolated { self?.cover.refresh() }
        })
        #endif
    }

    func toggle() {
        if isDesktopHidden { show() } else { hide() }
    }

    func hide() {
        log.info("hide requested")
        #if APPSTORE
        cover.cover()
        preferences.coverActive = true
        isDesktopHidden = true
        #else
        setFinderCreatesDesktop(false)
        isDesktopHidden = true
        applyWallpaperIfNeeded()
        #endif
    }

    func show() {
        log.info("show requested")
        #if APPSTORE
        cover.uncover()
        preferences.coverActive = false
        isDesktopHidden = false
        #else
        setFinderCreatesDesktop(true)
        isDesktopHidden = false
        lastError = wallpaper.restoreOriginals()
        #endif
    }

    /// Reacts to the wallpaper settings changing while the desktop is already hidden.
    func wallpaperSettingsChanged() {
        guard isDesktopHidden else { return }
        #if APPSTORE
        cover.refresh()
        #else
        if preferences.useCustomWallpaper {
            applyWallpaperIfNeeded()
        } else {
            lastError = wallpaper.restoreOriginals()
        }
        #endif
    }

    private func displaysChanged() {
        #if APPSTORE
        cover.refresh()
        #else
        applyWallpaperIfNeeded()
        #endif
    }

    #if !APPSTORE
    private func applyWallpaperIfNeeded() {
        guard isDesktopHidden, preferences.useCustomWallpaper else { return }
        lastError = wallpaper.applyCustom()
    }

    // MARK: - Finder

    private static let finderDomain = "com.apple.finder" as CFString
    private static let createDesktopKey = "CreateDesktop" as CFString

    /// Finder's default is to draw the desktop; the key only exists once something has changed it.
    private static func finderCreatesDesktop() -> Bool {
        guard let value = CFPreferencesCopyAppValue(createDesktopKey, finderDomain) else { return true }
        if let number = value as? NSNumber { return number.boolValue }
        if let string = value as? String { return !["false", "no", "0"].contains(string.lowercased()) }
        return true
    }

    private func setFinderCreatesDesktop(_ creates: Bool) {
        CFPreferencesSetAppValue(Self.createDesktopKey, creates ? kCFBooleanTrue : kCFBooleanFalse, Self.finderDomain)
        let synced = CFPreferencesAppSynchronize(Self.finderDomain)
        log.info("Finder CreateDesktop set to \(creates) (synchronized: \(synced)); relaunching Finder")
        relaunchFinder()
    }

    private func relaunchFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                log.error("killall Finder exited with status \(process.terminationStatus)")
            }
        } catch {
            log.error("Couldn't run killall: \(error.localizedDescription)")
            lastError = "Couldn't restart Finder: \(error.localizedDescription)"
        }
    }
    #endif
}
