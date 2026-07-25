import AppKit

/// Keeps Launch Services metadata fresh and exposes the bundle icon for in-app UI.
/// Do not assign `NSApp.applicationIconImage` — macOS composes Dock icons from the
/// bundle `.icns` (mask, size, retina). Overriding it only while running causes blur
/// or a raw unmasked square.
enum AppIcon {
    static func install() {
        registerWithLaunchServices()
    }

    /// Loads the bundle icon at a logical point size for SwiftUI/AppKit views.
    static func loadImage(displaySize: CGFloat = 128) -> NSImage? {
        if let image = loadFromICNS(displaySize: displaySize) {
            return image
        }

        if let image = NSImage(named: NSImage.applicationIconName),
           image.isValid, image.size.width > 0 {
            image.size = NSSize(width: displaySize, height: displaySize)
            return image
        }

        return nil
    }

    private static func loadFromICNS(displaySize: CGFloat) -> NSImage? {
        guard let url = AppResources.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url),
              image.isValid, image.size.width > 0 else {
            return nil
        }
        image.size = NSSize(width: displaySize, height: displaySize)
        return image
    }

    /// Refreshes Launch Services metadata so Finder and System Settings pick up the icon.
    private static func registerWithLaunchServices() {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let lsregister = """
        /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
        """
        guard FileManager.default.isExecutableFile(atPath: lsregister) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregister)
        process.arguments = ["-f", "-R", "-trusted", Bundle.main.bundlePath]
        try? process.run()
    }
}
