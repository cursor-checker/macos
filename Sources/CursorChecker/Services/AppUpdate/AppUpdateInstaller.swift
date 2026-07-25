import AppKit
import CryptoKit
import Foundation

enum AppUpdateInstaller {
    private static let appBundleName = "CursorChecker.app"

    static func performUpdate(
        releaseURL: URL,
        downloadURL: URL?,
        checksumURL: URL?,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        guard let downloadURL else {
            NSWorkspace.shared.open(releaseURL)
            completion(.idle)
            return
        }
        guard let checksumURL else {
            NSWorkspace.shared.open(releaseURL)
            completion(.failed(L10n.updateChecksumRequired))
            return
        }

        completion(.downloading)
        ActivityJournal.shared.logAction(JournalLog.downloadUpdate)
        fetchExpectedSHA256(from: checksumURL) { checksumResult in
            DispatchQueue.main.async {
                switch checksumResult {
                case .failure(let error):
                    completion(.failed(error.localizedDescription))
                case .success(let expectedSHA256):
                    downloadAndInstall(
                        downloadURL: downloadURL,
                        expectedSHA256: expectedSHA256,
                        completion: completion
                    )
                }
            }
        }
    }

    private static func downloadAndInstall(
        downloadURL: URL,
        expectedSHA256: String,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        let started = Date()
        URLSession.shared.downloadTask(with: downloadURL) { location, response, error in
            let duration = Date().timeIntervalSince(started)
            let endpoint = ActivityJournal.sanitizeEndpoint(downloadURL.absoluteString)
            DispatchQueue.main.async {
                if let error {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error.localizedDescription
                    )
                    completion(.failed(error.localizedDescription))
                    return
                }
                guard let location else {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: L10n.updateArchiveMissing
                    )
                    completion(.failed(L10n.updateFileNotReceived))
                    return
                }
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                ActivityJournal.shared.logRequest(
                    endpoint: endpoint,
                    method: "GET",
                    statusCode: statusCode,
                    duration: duration
                )
                completion(.installing)
                ActivityJournal.shared.logAction(JournalLog.installUpdate)
                do {
                    try verifySHA256(of: location, expected: expectedSHA256)
                    let destination = try installDownloadedArchive(at: location)
                    ActivityJournal.shared.logAction(
                        JournalLog.updateInstalled,
                        detail: JournalLog.relaunchApp
                    )
                    relaunch(at: destination)
                } catch {
                    ActivityJournal.shared.logAction(
                        JournalLog.installUpdate,
                        success: false,
                        error: error.localizedDescription
                    )
                    completion(.failed(error.localizedDescription))
                }
            }
        }.resume()
    }

    private static func fetchExpectedSHA256(
        from url: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let started = Date()
        URLSession.shared.dataTask(with: url) { data, response, error in
            let duration = Date().timeIntervalSince(started)
            let endpoint = ActivityJournal.sanitizeEndpoint(url.absoluteString)
            if let error {
                ActivityJournal.shared.logRequest(
                    endpoint: endpoint,
                    method: "GET",
                    duration: duration,
                    error: error.localizedDescription
                )
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data else {
                ActivityJournal.shared.logRequest(
                    endpoint: endpoint,
                    method: "GET",
                    statusCode: (response as? HTTPURLResponse)?.statusCode,
                    duration: duration,
                    error: L10n.updateChecksumUnavailable
                )
                completion(.failure(AppUpdateError.checksumUnavailable))
                return
            }
            ActivityJournal.shared.logRequest(
                endpoint: endpoint,
                method: "GET",
                statusCode: http.statusCode,
                duration: duration
            )
            guard let text = String(data: data, encoding: .utf8) else {
                completion(.failure(AppUpdateError.checksumInvalid))
                return
            }
            do {
                completion(.success(try AppUpdateVersion.parseSHA256(from: text)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func verifySHA256(of fileURL: URL, expected: String) throws {
        let data = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual == expected.lowercased() else {
            throw AppUpdateError.checksumMismatch
        }
    }

    private static func installDownloadedArchive(at location: URL) throws -> URL {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("cursor-checker-update-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let archiveURL = tempRoot.appendingPathComponent("update.zip")
        try fileManager.moveItem(at: location, to: archiveURL)

        try validateZipEntries(at: archiveURL, destination: tempRoot)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", archiveURL.path, "-d", tempRoot.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateError.unzipFailed
        }

        guard let appBundle = findAppBundle(in: tempRoot) else {
            throw AppUpdateError.appNotFoundInArchive
        }
        try assertPath(appBundle, isContainedIn: tempRoot)

        let destination = preferredInstallLocation()
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.copyItem(at: appBundle, to: destination)
        stripQuarantine(at: destination)
        return destination
    }

    private static func validateZipEntries(at archiveURL: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", archiveURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateError.unzipFailed
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let destinationPath = destination.standardizedFileURL.path
        for line in output.split(whereSeparator: \.isNewline) {
            let entry = String(line)
            if entry.isEmpty { continue }
            if entry.hasPrefix("/") || entry.contains("../") || entry.contains("..\\") {
                throw AppUpdateError.unsafeArchivePath(entry)
            }
            let resolved = destination.appendingPathComponent(entry).standardizedFileURL.path
            guard resolved == destinationPath || resolved.hasPrefix(destinationPath + "/") else {
                throw AppUpdateError.unsafeArchivePath(entry)
            }
        }
    }

    private static func findAppBundle(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.lastPathComponent == appBundleName {
                return url
            }
        }
        return nil
    }

    private static func assertPath(_ url: URL, isContainedIn root: URL) throws {
        let rootPath = root.standardizedFileURL.path
        let resolved = url.standardizedFileURL.path
        guard resolved == rootPath || resolved.hasPrefix(rootPath + "/") else {
            throw AppUpdateError.unsafeArchivePath(url.path)
        }
    }

    private static func preferredInstallLocation() -> URL {
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/CursorChecker.app")
        if FileManager.default.fileExists(atPath: homeApps.path) {
            return homeApps
        }
        if let running = Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundleURL : nil {
            return running
        }
        return homeApps
    }

    private static func stripQuarantine(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", url.path]
        try? process.run()
        process.waitUntilExit()
    }

    private static func relaunch(at destination: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cursor-checker-relaunch-\(pid).sh")

        let script = """
        #!/bin/bash
        APP=\(shellQuote(destination.path))
        PID=\(pid)
        while kill -0 "$PID" 2>/dev/null; do
          sleep 0.1
        done
        /usr/bin/xattr -cr "$APP" 2>/dev/null || true
        /usr/bin/open "$APP"
        rm -f \(shellQuote(scriptURL.path))
        """

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
            NSWorkspace.shared.open(destination)
        }

        NSApp.terminate(nil)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
