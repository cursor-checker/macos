// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CursorChecker",
    defaultLocalization: "ru",
    platforms: [
        .macOS("15.0")
    ],
    targets: [
        .executableTarget(
            name: "CursorChecker",
            path: "Sources/CursorChecker",
            exclude: [
                "Localization/Localizable.xcstrings",
            ],
            resources: [
                .copy("Bundled/LICENSE.txt"),
                .copy("Bundled/CHANGELOG.md"),
                .copy("Bundled/CHANGELOG.en.md"),
                .process("Localization/en.lproj"),
                .process("Localization/ru.lproj"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
