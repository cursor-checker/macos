import Foundation
import AppKit

enum PollIntervalUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seconds: return L10n.pollUnitSeconds
        case .minutes: return L10n.pollUnitMinutes
        case .hours:   return L10n.pollUnitHours
        }
    }

    func toMinutes(_ value: Double) -> Double {
        switch self {
        case .seconds: return value / 60
        case .minutes: return value
        case .hours:   return value * 60
        }
    }

    /// Best-effort split of stored minutes into a whole-number amount + unit.
    static func decompose(minutes: Double) -> (amount: Double, unit: PollIntervalUnit) {
        if minutes >= 60, minutes.truncatingRemainder(dividingBy: 60) == 0 {
            return (minutes / 60, .hours)
        }
        let seconds = minutes * 60
        if minutes < 1, seconds == seconds.rounded(), seconds > 0 {
            return (seconds, .seconds)
        }
        if minutes == minutes.rounded(), minutes > 0 {
            return (minutes, .minutes)
        }
        return (minutes, .minutes)
    }

    /// Minimum supported poll interval (15 seconds).
    static let minimumPollMinutes: Double = 0.25
}

enum MenuBarPercentMode: String, Codable, CaseIterable, Identifiable {
    case total
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return L10n.menuBarModeTotal
        case .daily: return L10n.menuBarModeDaily
        }
    }
}

struct MenuPopupFields: Codable, Equatable {
    var showToday = true
    var showTotalSpent = true
    var showRemaining = true
    var showAutoApi = true
    var showSpendUSD = true
    var showCycleEnd = true
    /// Custom row order in the menu-bar dropdown; nil means default enum order.
    var fieldOrder: [String]?
}

enum MenuPopupField: String, Codable, CaseIterable, Identifiable {
    case today, totalSpent, remaining, autoApi, spendUSD, cycleEnd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:       return L10n.menuFieldToday
        case .totalSpent:  return L10n.menuFieldTotalSpent
        case .remaining:   return L10n.menuFieldRemaining
        case .autoApi:     return L10n.menuFieldAutoApi
        case .spendUSD:    return L10n.menuFieldSpendUSD
        case .cycleEnd:    return L10n.menuFieldCycleEnd
        }
    }
}

extension MenuPopupFields {
    static func normalizedFieldOrder(_ order: [String]?) -> [MenuPopupField] {
        let known = Set(MenuPopupField.allCases)
        var result: [MenuPopupField] = []
        if let order {
            for raw in order {
                guard let field = MenuPopupField(rawValue: raw),
                      known.contains(field),
                      !result.contains(field) else { continue }
                result.append(field)
            }
        }
        for field in MenuPopupField.allCases where !result.contains(field) {
            result.append(field)
        }
        return result
    }

    var resolvedFieldOrder: [MenuPopupField] {
        Self.normalizedFieldOrder(fieldOrder)
    }

    mutating func moveFields(from source: IndexSet, to destination: Int) {
        var order = resolvedFieldOrder
        order.move(fromOffsets: source, toOffset: destination)
        fieldOrder = order.map(\.rawValue)
    }

    func isEnabled(_ field: MenuPopupField) -> Bool {
        switch field {
        case .today:       return showToday
        case .totalSpent:  return showTotalSpent
        case .remaining:   return showRemaining
        case .autoApi:     return showAutoApi
        case .spendUSD:    return showSpendUSD
        case .cycleEnd:    return showCycleEnd
        }
    }

    mutating func setEnabled(_ field: MenuPopupField, _ enabled: Bool) {
        switch field {
        case .today:       showToday = enabled
        case .totalSpent:  showTotalSpent = enabled
        case .remaining:   showRemaining = enabled
        case .autoApi:     showAutoApi = enabled
        case .spendUSD:    showSpendUSD = enabled
        case .cycleEnd:    showCycleEnd = enabled
        }
    }
}

struct TelegramConfig: Codable {
    var enabled: Bool = false
    var botToken: String = ""
    var chatId: String = ""
}

enum UpdateChannel: String, Codable, CaseIterable, Identifiable {
    case stable
    case beta

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable: return L10n.updateChannelStable
        case .beta:   return L10n.updateChannelBeta
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case ru
    case en

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .ru: return "ru"
        case .en: return "en"
        }
    }

    var displayName: String {
        switch self {
        case .system: return L10n.appLanguageSystem
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.appThemeSystem
        case .light:  return L10n.appThemeLight
        case .dark:   return L10n.appThemeDark
        }
    }

    func apply() {
        NSApp.appearance = nsAppearance
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

struct Config: Codable {
    /// How often to poll usage, in minutes.
    var pollIntervalMinutes: Double = 15

    /// Warn when today's growth of the cycle usage crosses each multiple of this
    /// many percent. e.g. 5 => alert at +5%, +10%, +15% spent today.
    /// Ignored while `dailyThresholdSmartMode` is enabled.
    var dailyThresholdPercent: Double = 5
    /// Derive the daily threshold as remaining quota ÷ remaining days.
    var dailyThresholdSmartMode: Bool?
    /// When smart mode is on, count only Mon–Fri toward remaining days.
    var dailyThresholdWorkingDaysOnly: Bool?

    var macNotificationsEnabled: Bool = true
    var telegram: TelegramConfig = TelegramConfig()
    /// Optional for backward compatibility with older config.json files.
    var menuBarPercentMode: MenuBarPercentMode?
    var menuBarVisible: Bool?
    /// Show ⚠️ in the menu-bar title when today's usage crosses the daily threshold.
    var menuBarWarningIconEnabled: Bool?
    var menuPopupFields: MenuPopupFields?
    var journalLoggingEnabled: Bool?
    var updateChannel: UpdateChannel?
    var appTheme: AppTheme?
    var appLanguage: AppLanguage?
    /// `false` after «Отозвать токен»; blocks auto-restore on launch.
    var cursorConnectionEnabled: Bool?
    /// Cursor account email — stored in config.json (not a secret).
    var cursorStoredEmail: String?

    var resolvedDailyThresholdSmartMode: Bool { dailyThresholdSmartMode ?? false }
    var resolvedDailyThresholdWorkingDaysOnly: Bool { dailyThresholdWorkingDaysOnly ?? false }

    var resolvedMenuBarPercentMode: MenuBarPercentMode { menuBarPercentMode ?? .total }
    var resolvedMenuBarVisible: Bool { menuBarVisible ?? true }
    var resolvedMenuBarWarningIconEnabled: Bool { menuBarWarningIconEnabled ?? true }
    var resolvedMenuPopupFields: MenuPopupFields { menuPopupFields ?? MenuPopupFields() }
    var resolvedJournalLoggingEnabled: Bool { journalLoggingEnabled ?? false }
    var resolvedUpdateChannel: UpdateChannel { updateChannel ?? .stable }
    var resolvedAppTheme: AppTheme { appTheme ?? .system }
    var resolvedAppLanguage: AppLanguage { appLanguage ?? .system }
    var resolvedCursorConnectionEnabled: Bool {
        if let cursorConnectionEnabled { return cursorConnectionEnabled }
        return CursorUsageClient.hasStoredCredentials
    }

    // MARK: - Persistence

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("cursor-checker", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("config.json") }
    static var secretsFileURL: URL { SecretStore.fileURL }

    /// Secret key for the Telegram bot token in `secrets.json`.
    static let telegramSecretAccount = "telegram-bot-token"
    static let cursorCredentialsAccount = "cursor-credentials"
    /// Legacy secret keys migrated from Keychain into `secrets.json`.
    static let legacyCursorTokenAccount = "cursor-access-token"
    static let legacyCursorEmailAccount = "cursor-email"

    static func loadJournalLoggingEnabled() -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else {
            return false
        }
        return cfg.resolvedJournalLoggingEnabled
    }

    static func load() -> Config {
        ensureDirectory()
        guard let data = try? Data(contentsOf: fileURL),
              var cfg = try? JSONDecoder().decode(Config.self, from: data) else {
            let fresh = Config()
            fresh.save()
            return fresh
        }
        // Keep the bot token out of config.json. Migrate legacy plaintext values
        // into secrets.json and scrub the config file.
        let fileToken = cfg.telegram.botToken
        if !fileToken.isEmpty {
            SecretStore.set(fileToken, account: telegramSecretAccount)
            cfg.telegram.botToken = fileToken
            cfg.save()
        } else if cfg.telegram.enabled {
            cfg.telegram.botToken = SecretStore.get(telegramSecretAccount) ?? ""
        } else {
            cfg.telegram.botToken = ""
        }
        return cfg
    }

    func save() {
        Config.ensureDirectory()
        // Never write the bot token to config.json: it lives in secrets.json.
        var onDisk = self
        onDisk.telegram.botToken = ""
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(onDisk) {
            try? data.write(to: Config.fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: Config.fileURL.path)
        }
    }

    static func ensureDirectory() {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        // Enforce perms even if the directory already existed with looser ones.
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
}
