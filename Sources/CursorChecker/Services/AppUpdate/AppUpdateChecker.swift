import Foundation

enum AppUpdateChecker {
    static func check(
        repository: String,
        channel: UpdateChannel,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        switch channel {
        case .stable:
            fetchRelease(
                from: stableReleaseURL(repository: repository),
                repository: repository,
                channel: channel,
                completion: completion
            )
        case .beta:
            fetchBetaRelease(repository: repository, completion: completion)
        }
    }

    private static func stableReleaseURL(repository: String) -> URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    private static func fetchBetaRelease(
        repository: String,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=30")!
        performReleaseRequest(url: url, repository: repository, channel: .beta) { releases, failure in
            if let failure {
                completion(failure)
                return
            }
            guard let release = releases?.first(where: \.prerelease) else {
                completion(.noReleases)
                return
            }
            completion(evaluate(release: release, channel: .beta))
        }
    }

    private static func fetchRelease(
        from url: URL,
        repository: String,
        channel: UpdateChannel,
        completion: @escaping (AppUpdateStatus) -> Void
    ) {
        performReleaseRequest(url: url, repository: repository, channel: channel) { releases, failure in
            if let failure {
                completion(failure)
                return
            }
            guard let release = releases?.first else {
                completion(.noReleases)
                return
            }
            completion(evaluate(release: release, channel: channel))
        }
    }

    private static func performReleaseRequest(
        url: URL,
        repository: String,
        channel: UpdateChannel,
        completion: @escaping (_ releases: [GitHubRelease]?, _ failure: AppUpdateStatus?) -> Void
    ) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CursorChecker/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        let started = Date()
        URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(started)
            let endpoint = url.absoluteString
            DispatchQueue.main.async {
                if let error {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error.localizedDescription
                    )
                    completion(nil, .failed(error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: L10n.updateInvalidServerResponse
                    )
                    completion(nil, .failed(L10n.updateInvalidServerResponse))
                    return
                }
                if http.statusCode == 404 {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        statusCode: http.statusCode,
                        duration: duration,
                        error: L10n.updateReleasesNotFound
                    )
                    completion(nil, .noReleases)
                    return
                }
                guard http.statusCode == 200, let data else {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        statusCode: http.statusCode,
                        duration: duration,
                        error: "HTTP \(http.statusCode)"
                    )
                    completion(nil, .failed(L10n.updateServerCode(http.statusCode)))
                    return
                }
                do {
                    let releases: [GitHubRelease]
                    if channel == .stable, url == stableReleaseURL(repository: repository) {
                        releases = [try JSONDecoder().decode(GitHubRelease.self, from: data)]
                    } else {
                        releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
                    }
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        statusCode: http.statusCode,
                        duration: duration
                    )
                    completion(releases, nil)
                } catch {
                    ActivityJournal.shared.logRequest(
                        endpoint: endpoint,
                        method: "GET",
                        statusCode: http.statusCode,
                        duration: duration,
                        error: L10n.updateGitHubParseFailed
                    )
                    completion(nil, .failed(L10n.updateGitHubParseFailed))
                }
            }
        }.resume()
    }

    private static func evaluate(release: GitHubRelease, channel: UpdateChannel) -> AppUpdateStatus {
        let latest = AppUpdateVersion.normalized(release.tagName)
        let current = AppUpdateVersion.normalized(AppInfo.version)
        if !AppUpdateVersion.isReleaseNewer(latest, than: current) {
            return .upToDate
        }

        let zipName = AppUpdateVersion.zipAssetName(version: latest)
        let checksumName = AppUpdateVersion.checksumAssetName(version: latest)
        guard let zipAsset = release.assets.first(where: { $0.name == zipName }),
              let downloadURL = URL(string: zipAsset.browserDownloadURL) else {
            return .failed(L10n.updateMissingZip(zipName))
        }
        let checksumURL = release.assets
            .first(where: { $0.name == checksumName })
            .flatMap { URL(string: $0.browserDownloadURL) }

        return .updateAvailable(
            version: latest,
            releaseURL: URL(string: release.htmlURL)!,
            downloadURL: downloadURL,
            checksumURL: checksumURL,
            channel: channel,
            releaseNotes: release.notes
        )
    }
}
