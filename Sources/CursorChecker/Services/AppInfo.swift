import Foundation

/// Bundle metadata shown in the About settings pane.
enum AppInfo {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Cursor Checker"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var versionLabel: String {
        build == version ? version : "\(version) (\(build))"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.nokk3r.cursorchecker"
    }

    static let companyName = "Rete studio"
    static let copyrightYear = "2026"

    static var copyrightNotice: String {
        "© \(copyrightYear) \(companyName)"
    }

    static var licenseURL: URL? {
        AppResources.url(forResource: "LICENSE", withExtension: "txt")
    }

    static var licenseText: String {
        guard let url = licenseURL,
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return L10n.licenseNotFound
        }
        return text
    }
}
