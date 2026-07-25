import AppKit

/// Ensures only one menu-bar instance runs at a time.
enum SingleInstance {
    static func exitIfAnotherInstanceIsRunning() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let myPath = Bundle.main.bundleURL.standardizedFileURL.path
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: AppInfo.bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        guard !others.isEmpty else { return }

        if let sameBuild = others.first(where: {
            $0.bundleURL?.standardizedFileURL.path == myPath
        }) {
            sameBuild.activate()
            exit(0)
        }

        for app in others {
            app.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)
    }
}
