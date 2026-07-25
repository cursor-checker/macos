import Foundation
import ServiceManagement

/// Registers the app to open at login via `SMAppService` (System Settings shows
/// the real app name and icon). Legacy LaunchAgent plists are removed on migration.
enum LaunchAtLogin {
    enum Error: LocalizedError {
        case notBundledApp
        case registrationFailed(String)

        var errorDescription: String? {
            switch self {
            case .notBundledApp:
                return L10n.launchAtLoginNotBundled
            case .registrationFailed(let detail):
                return detail
            }
        }
    }

    static var isSupported: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    static var isEnabled: Bool {
        guard isSupported else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Drops a custom LaunchAgent (direct binary, `open`, `KeepAlive`, …) and
    /// re-registers through `SMAppService` when autostart was enabled.
    static func migrateLaunchAgentIfNeeded() {
        guard isSupported else { return }
        guard FileManager.default.fileExists(atPath: legacyPlistURL.path) else { return }

        let wasEnabled = legacyLaunchAgentPointsToThisApp()
        removeLegacyLaunchAgent()

        guard wasEnabled, SMAppService.mainApp.status != .enabled else { return }
        _ = setEnabled(true)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Result<Void, Error> {
        guard isSupported else { return .failure(.notBundledApp) }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            removeLegacyLaunchAgent()
            return .success(())
        } catch {
            return .failure(.registrationFailed(error.localizedDescription))
        }
    }

    // MARK: - Legacy LaunchAgent cleanup

    private static var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(AppInfo.bundleIdentifier).plist")
    }

    private static func legacyLaunchAgentPointsToThisApp() -> Bool {
        guard let data = try? Data(contentsOf: legacyPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String] else {
            return false
        }

        let ourApp = Bundle.main.bundleURL.standardizedFileURL.path
        let ourExe = Bundle.main.executableURL?.standardizedFileURL.path

        if let agentApp = legacyLaunchAgentAppPath(from: args), agentApp == ourApp {
            return true
        }
        return args.first == ourExe
    }

    private static func legacyLaunchAgentAppPath(from args: [String]) -> String? {
        if args.first == "/usr/bin/open" {
            return args
                .first { $0.hasSuffix(".app") }
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        }

        guard let binary = args.first else { return nil }
        var url = URL(fileURLWithPath: binary).deletingLastPathComponent()
        url = url.deletingLastPathComponent()
        url = url.deletingLastPathComponent()
        guard url.pathExtension == "app" else { return nil }
        return url.standardizedFileURL.path
    }

    private static func removeLegacyLaunchAgent() {
        unloadLegacyLaunchAgent()
        try? FileManager.default.removeItem(at: legacyPlistURL)
    }

    private static func unloadLegacyLaunchAgent() {
        let domain = "gui/\(getuid())"
        let path = legacyPlistURL.path
        _ = runLaunchctl(["bootout", domain, path])
        _ = runLaunchctl(["unload", path])
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
