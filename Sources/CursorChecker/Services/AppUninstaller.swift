import AppKit
import Foundation
import ServiceManagement

/// Removes the app bundle, LaunchAgent, local data and stored secrets.
/// A short-lived shell script finishes cleanup after the process exits.
enum AppUninstaller {

    static func confirmAndUninstall() {
        let alert = NSAlert()
        alert.messageText = L10n.uninstallTitle(AppInfo.displayName)
        alert.informativeText = L10n.uninstallBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.commonDelete)
        alert.addButton(withTitle: L10n.commonCancel)
        alert.buttons.first?.hasDestructiveAction = true

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        uninstallAndTerminate()
    }

    static func uninstallAndTerminate() {
        try? SMAppService.mainApp.unregister()
        SecretStore.deleteAll()

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-checker-uninstall-\(ProcessInfo.processInfo.processIdentifier).sh")
        let script = makeCleanupScript()

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            try process.run()
        } catch {
            let errorAlert = NSAlert()
            errorAlert.messageText = L10n.uninstallFailed
            errorAlert.informativeText = error.localizedDescription
            errorAlert.alertStyle = .critical
            errorAlert.runModal()
            return
        }

        NSApp.terminate(nil)
    }

    private static func makeCleanupScript() -> String {
        let home = NSHomeDirectory()
        let launchAgent = "\(home)/Library/LaunchAgents/\(AppInfo.bundleIdentifier).plist"
        let appSupport = Config.directory.path
        let legacyAppSupport = "\(home)/Library/Application Support/\(ActivityJournal.legacyDirectoryNameForCleanup)"
        let installedApp = "\(home)/Applications/CursorChecker.app"
        let runningApp = Bundle.main.bundlePath

        var pathsToRemove = [installedApp, runningApp, appSupport, legacyAppSupport]
        pathsToRemove = Array(Set(pathsToRemove))

        let removeLines = pathsToRemove
            .map { "rm -rf \(shellQuote($0))" }
            .joined(separator: "\n")

        return """
        #!/bin/bash
        set -e
        sleep 0.5
        launchctl bootout "gui/$(id -u)" \(shellQuote(launchAgent)) 2>/dev/null || \
          launchctl unload \(shellQuote(launchAgent)) 2>/dev/null || true
        rm -f \(shellQuote(launchAgent))
        \(removeLines)
        rm -f \(shellQuote("$0"))
        """
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
