import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Hides or shows the desktop from anywhere. ⌃⌥⌘D by default; changeable in Settings.
    static let toggleDesktop = Self("toggleDesktop", default: .init(.d, modifiers: [.control, .option, .command]))
}
