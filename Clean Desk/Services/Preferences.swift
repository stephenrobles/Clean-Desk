import Foundation
import Observation

/// User settings, persisted in UserDefaults.
@Observable
final class Preferences {
    private enum Key {
        static let showDockIcon = "showDockIcon"
        static let useCustomWallpaper = "useCustomWallpaper"
        static let customWallpaperPath = "customWallpaperPath"
        static let customWallpaperBookmark = "customWallpaperBookmark"
        static let originalWallpapers = "originalWallpapers"
        static let coverActive = "coverActive"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    /// Show the app in the Dock as well as the menu bar. Off by default: it is a menu bar utility.
    var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Key.showDockIcon) }
    }

    /// Swap in `customWallpaperURL` while the desktop is hidden, and put the previous wallpaper back after.
    var useCustomWallpaper: Bool {
        didSet { defaults.set(useCustomWallpaper, forKey: Key.useCustomWallpaper) }
    }

    /// The image chosen in Settings. Stored as a bookmark so the sandboxed build keeps access to it
    /// across launches; the path is kept alongside for display and as a fallback.
    var customWallpaperURL: URL? {
        didSet {
            defaults.set(customWallpaperURL?.path, forKey: Key.customWallpaperPath)
            defaults.set(customWallpaperURL.flatMap { try? $0.bookmarkData(options: Self.bookmarkOptions) }, forKey: Key.customWallpaperBookmark)
            _ = customWallpaperURL?.startAccessingSecurityScopedResource()
        }
    }

    /// The wallpaper each display had before Clean Desk swapped in the custom one, keyed by display ID.
    /// Persisted so the originals survive a relaunch (or crash) and can still be restored.
    var originalWallpapers: [String: String] {
        didSet { defaults.set(originalWallpapers, forKey: Key.originalWallpapers) }
    }

    /// App Store build: whether the desktop was covered when the app last ran, so launching at login
    /// brings the cover straight back.
    var coverActive: Bool {
        didSet { defaults.set(coverActive, forKey: Key.coverActive) }
    }

    init() {
        showDockIcon = defaults.bool(forKey: Key.showDockIcon)
        useCustomWallpaper = defaults.bool(forKey: Key.useCustomWallpaper)
        originalWallpapers = defaults.dictionary(forKey: Key.originalWallpapers) as? [String: String] ?? [:]
        coverActive = defaults.bool(forKey: Key.coverActive)
        customWallpaperURL = Self.resolveWallpaper(bookmark: defaults.data(forKey: Key.customWallpaperBookmark),
                                                   path: defaults.string(forKey: Key.customWallpaperPath))
        _ = customWallpaperURL?.startAccessingSecurityScopedResource()
    }

    #if APPSTORE
    private static let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
    #else
    private static let bookmarkOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withoutUI]
    #endif

    private static func resolveWallpaper(bookmark: Data?, path: String?) -> URL? {
        var stale = false
        if let bookmark, let url = try? URL(resolvingBookmarkData: bookmark, options: resolutionOptions, bookmarkDataIsStale: &stale) {
            return url
        }
        return path.map { URL(fileURLWithPath: $0) }
    }
}
