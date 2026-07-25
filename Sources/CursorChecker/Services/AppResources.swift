import Foundation

/// Resolves bundled files for SPM executables packaged as `.app`.
enum AppResources {
    static var directory: URL? {
        appResourcesDirectory
    }

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let filename = "\(name).\(ext)"

        if let url = appResourcesDirectory?.appendingPathComponent(filename),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        if let url = moduleResourceURL(name: name, extension: ext) {
            return url
        }

        return nil
    }

    /// Bundle that holds compiled `Localizable.strings` for SPM + `.app` packaging.
    static var localizationBundle: Bundle {
        if let url = moduleResourceBundleURL, let bundle = Bundle(url: url) {
            return bundle
        }
        return .module
    }

    private static var appResourcesDirectory: URL? {
        let main = Bundle.main

        if let url = main.resourceURL, url.lastPathComponent == "Resources" {
            return url
        }

        if main.bundlePath.hasSuffix(".app") {
            let resources = URL(fileURLWithPath: main.bundlePath)
                .appendingPathComponent("Contents/Resources", isDirectory: true)
            if FileManager.default.fileExists(atPath: resources.path) {
                return resources
            }
        }

        if main.bundleURL.pathExtension == "app" {
            let resources = main.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
            if FileManager.default.fileExists(atPath: resources.path) {
                return resources
            }
        }

        if let exec = main.executableURL {
            let resources = exec
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources", isDirectory: true)
            if FileManager.default.fileExists(atPath: resources.path) {
                return resources
            }
        }

        return nil
    }

    /// SPM resource bundle copied next to the `.app` wrapper during build.
    private static var moduleResourceBundleURL: URL? {
        let bundleName = "CursorChecker_CursorChecker.bundle"
        var candidates: [URL] = []

        if Bundle.main.bundlePath.hasSuffix(".app") {
            let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            candidates.append(appURL.appendingPathComponent("Contents/Resources/\(bundleName)", isDirectory: true))
            candidates.append(appURL.appendingPathComponent(bundleName, isDirectory: true))
        }

        if let exec = Bundle.main.executableURL {
            candidates.append(exec.deletingLastPathComponent().appendingPathComponent(bundleName, isDirectory: true))
        }

        for bundleURL in candidates where FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }

        return nil
    }

    private static func moduleResourceURL(name: String, extension ext: String) -> URL? {
        guard let bundleURL = moduleResourceBundleURL,
              let bundle = Bundle(url: bundleURL) else { return nil }
        return bundle.url(forResource: name, withExtension: ext)
    }
}
