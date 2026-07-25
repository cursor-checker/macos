import Foundation

enum AppUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(
        version: String,
        releaseURL: URL,
        downloadURL: URL?,
        checksumURL: URL?,
        channel: UpdateChannel,
        releaseNotes: String?
    )
    case noReleases
    case downloading
    case installing
    case failed(String)
}

enum AppUpdateError: LocalizedError {
    case unzipFailed
    case appNotFoundInArchive
    case checksumUnavailable
    case checksumInvalid
    case checksumMismatch
    case unsafeArchivePath(String)

    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return L10n.updateErrorUnzipFailed
        case .appNotFoundInArchive:
            return L10n.updateErrorAppNotFound
        case .checksumUnavailable:
            return L10n.updateErrorChecksumUnavailable
        case .checksumInvalid:
            return L10n.updateErrorChecksumInvalid
        case .checksumMismatch:
            return L10n.updateErrorChecksumMismatch
        case .unsafeArchivePath(let path):
            return L10n.updateErrorUnsafePath(path)
        }
    }
}
