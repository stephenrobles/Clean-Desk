import KeyboardShortcuts
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(DesktopController.self) private var desktop
    @Environment(AppUpdater.self) private var updater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        @Bindable var preferences = preferences
        @Bindable var updater = updater
        Form {
            Section("Desktop") {
                Toggle("Hide desktop icons", isOn: Binding(
                    get: { desktop.isDesktopHidden },
                    set: { $0 ? desktop.hide() : desktop.show() }
                ))
                KeyboardShortcuts.Recorder("Keyboard shortcut", name: .toggleDesktop)
                Text(desktopDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = desktop.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            }

            Section("Wallpaper") {
                Toggle("Use a custom wallpaper while hidden", isOn: $preferences.useCustomWallpaper)
                    .onChange(of: preferences.useCustomWallpaper) { _, _ in desktop.wallpaperSettingsChanged() }
                LabeledContent {
                    Button("Choose…") { chooseWallpaper() }
                } label: {
                    HStack(spacing: 10) {
                        WallpaperThumbnail(url: preferences.customWallpaperURL)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preferences.customWallpaperURL?.lastPathComponent ?? "No image chosen")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text(wallpaperDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!preferences.useCustomWallpaper)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Show in Dock", isOn: $preferences.showDockIcon)
            }

            #if !APPSTORE
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $updater.automaticallyChecksForUpdates)
                LabeledContent {
                    Button("Check for Updates…") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                } label: {
                    Text("\(AppInfo.name) \(AppInfo.version)")
                    Text("New versions install from beardfm.app.")
                }
            }
            #endif

            Section {
                LabeledContent {
                    Button("Quit") { NSApp.terminate(nil) }
                } label: {
                    Text("Quit \(AppInfo.name)")
                    Text("Shows your desktop again and removes the menu bar icon until you open the app.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    #if APPSTORE
    private let desktopDescription = "Covers every file, folder and disk on the desktop with a clean backdrop so only the wallpaper shows. Nothing is moved; everything is back the moment you show the desktop again."
    private let wallpaperDescription = "Shown on every display while the desktop is hidden. Without one, Clean Desk uses your current wallpaper when it can read the file, and a plain blue backdrop otherwise."
    #else
    private let desktopDescription = "Hides every file, folder and disk on the desktop so only the wallpaper shows. Finder restarts for a moment each time, which closes any open Finder windows."
    private let wallpaperDescription = "Shown on every display while the desktop is hidden. Your usual wallpaper comes back when icons return."
    #endif

    private func chooseWallpaper() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Wallpaper"
        panel.prompt = "Use"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = preferences.customWallpaperURL?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        preferences.customWallpaperURL = url
        desktop.wallpaperSettingsChanged()
    }
}

private struct WallpaperThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 36)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator))
    }
}
