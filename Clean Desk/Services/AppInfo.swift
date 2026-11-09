import Foundation

enum AppInfo {
    static let name = "Clean Desk"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
