import Foundation

/// English-only strings written into the activity journal (not localized with UI).
enum JournalLog {
    static let connectCursor = "Connecting to Cursor"
    static let readLocalToken = "Reading local token"
    static let accessGranted = "Access granted"
    static let revokeToken = "Revoke Cursor token"
    static let pollUsage = "Poll usage"
    static let pollManual = "Requested manually"
    static let sendNotifications = "Send notifications"
    static let testMac = "Test macOS notification"
    static let testTelegram = "Test Telegram notification"
    static let saveSettings = "Save settings"
    static let checkUpdates = "Check for updates"
    static let downloadUpdate = "Download update"
    static let installUpdate = "Install update"
    static let updateInstalled = "Update installed"
    static let relaunchApp = "Relaunch app"
    static let launchAtLoginEnabled = "Launch at login enabled"
    static let launchAtLoginDisabled = "Launch at login disabled"
    static let actionFailed = "Failed"

    static func notificationCount(_ count: Int) -> String {
        "Count: \(count)"
    }

    static func configChangeSummary(from config: Config) -> String {
        var parts: [String] = []
        parts.append("Poll: \(Int(config.pollIntervalMinutes)) min")
        if config.resolvedDailyThresholdSmartMode {
            parts.append("Threshold: smart")
            if config.resolvedDailyThresholdWorkingDaysOnly {
                parts.append("working days")
            }
        } else {
            parts.append("Threshold: \(Int(config.dailyThresholdPercent))%")
        }
        parts.append(config.macNotificationsEnabled ? "macOS: on" : "macOS: off")
        parts.append(config.telegram.enabled ? "Telegram: on" : "Telegram: off")
        parts.append(config.resolvedMenuBarVisible ? "Menu: visible" : "Menu: hidden")
        parts.append(configSummaryUpdates(config.resolvedUpdateChannel))
        return parts.joined(separator: " ")
    }

    private static func configSummaryUpdates(_ channel: UpdateChannel) -> String {
        switch channel {
        case .stable: return "Updates: Stable"
        case .beta: return "Updates: Beta"
        }
    }
}
