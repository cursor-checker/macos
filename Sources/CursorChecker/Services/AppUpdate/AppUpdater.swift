import Foundation

/// Checks GitHub releases and can install a downloaded `.zip` asset.
final class AppUpdater {
    static let shared = AppUpdater()
    static let repository = "cursor-checker/macos"

    private init() {}

    func checkForUpdates(
        channel: UpdateChannel = .stable,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        AppUpdateChecker.check(
            repository: Self.repository,
            channel: channel,
            completion: completion
        )
    }

    func performUpdate(
        releaseURL: URL,
        downloadURL: URL?,
        checksumURL: URL?,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        AppUpdateInstaller.performUpdate(
            releaseURL: releaseURL,
            downloadURL: downloadURL,
            checksumURL: checksumURL,
            completion: completion
        )
    }
}
