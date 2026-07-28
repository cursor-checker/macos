import AppKit
import Combine

/// Single source of truth shared by the menu bar, the details window and the
/// settings window. Owns polling, alerting and config/state persistence so the
/// SwiftUI views can just observe it.
final class AppModel: ObservableObject {

    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isCursorConnected = false
    @Published private(set) var isConnectingCursor = false
    @Published private(set) var cursorConnectionError: String?
    @Published private(set) var cursorEmail: String?
    @Published private(set) var state: UsageState
    @Published private(set) var config: Config
    @Published var settingsTab: SettingsTab = .connection
    @Published var showChangelogSheet = false
    @Published var showLicenseSheet = false
    @Published var changelogSheetTitle = ""
    @Published var changelogSheetUseBundled = true
    @Published var changelogSheetEntries: [ChangelogEntry] = []
    @Published private(set) var uiLocaleRevision = UUID()
    /// Incremented when the settings window closes so `SettingsView` can reset back/forward history.
    @Published private(set) var settingsNavigationEpoch = 0

    /// Called on the main thread whenever anything the menu bar shows changed.
    var onChange: (() -> Void)?

    private var timer: Timer?
    private var configLogWorkItem: DispatchWorkItem?

    init() {
        config = Config.load()
        state = UsageState.load()
        ActivityJournal.shared.setLoggingEnabled(config.resolvedJournalLoggingEnabled)
        config.resolvedAppTheme.apply()
        applyLanguage(from: config)
    }

    // MARK: - Lifecycle

    func start() {
        restoreCursorConnectionIfNeeded()
        onChange?()
    }

    func requestCloseSettingsSheets() {
        showChangelogSheet = false
        showLicenseSheet = false
    }

    func resetSettingsNavigation() {
        requestCloseSettingsSheets()
        changelogSheetTitle = ""
        changelogSheetUseBundled = true
        changelogSheetEntries = []
        settingsNavigationEpoch += 1
    }

    func presentBundledChangelog() {
        changelogSheetTitle = L10n.aboutChangelog
        changelogSheetUseBundled = true
        showChangelogSheet = true
    }

    func presentUpdateNotes(version: String, text: String) {
        changelogSheetTitle = L10n.aboutWhatsNewIn(version)
        changelogSheetUseBundled = false
        changelogSheetEntries = Changelog.parseEntries(from: text)
        showChangelogSheet = true
    }

    // MARK: - Cursor connection

    func connectCursor() {
        guard !isCursorConnected, !isConnectingCursor else { return }
        isConnectingCursor = true
        cursorConnectionError = nil
        ActivityJournal.shared.logAction(JournalLog.connectCursor, detail: JournalLog.readLocalToken)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let token = CursorUsageClient.readTokenFromCursor()
            let email = CursorUsageClient.cachedEmailFromCursor()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnectingCursor = false
                guard let token, !token.isEmpty else {
                    self.cursorConnectionError = UsageError.noToken.description
                    ActivityJournal.shared.logAction(
                        JournalLog.connectCursor,
                        success: false,
                        error: UsageError.noToken.journalDescription
                    )
                    self.onChange?()
                    return
                }
                if let exp = CursorUsageClient.tokenExpiry(token), exp < Date() {
                    self.cursorConnectionError = UsageError.tokenExpired.description
                    ActivityJournal.shared.logAction(
                        JournalLog.connectCursor,
                        success: false,
                        error: UsageError.tokenExpired.journalDescription
                    )
                    self.onChange?()
                    return
                }
                CursorUsageClient.saveToken(token)
                self.saveCursorEmail(email)
                self.setCursorConnectionEnabled(true)
                self.activateCursorConnection(email: email)
                ActivityJournal.shared.logAction(JournalLog.connectCursor, detail: JournalLog.accessGranted)
                self.onChange?()
            }
        }
    }

    func disconnectCursor() {
        guard isCursorConnected || isConnectingCursor else { return }
        isConnectingCursor = false
        isCursorConnected = false
        cursorEmail = nil
        cursorConnectionError = nil
        snapshot = nil
        lastError = nil
        isRefreshing = false
        timer?.invalidate()
        timer = nil
        CursorUsageClient.clearStoredToken()
        config.cursorStoredEmail = nil
        config.save()
        setCursorConnectionEnabled(false)
        ActivityJournal.shared.logAction(JournalLog.revokeToken)
        onChange?()
    }

    private func restoreCursorConnectionIfNeeded() {
        guard !isCursorConnected else { return }
        if config.cursorConnectionEnabled == false { return }

        guard let token = CursorUsageClient.storedToken(),
              !token.isEmpty,
              !Self.isTokenExpired(token) else {
            return
        }

        activateCursorConnection(email: config.cursorStoredEmail)
    }

    private func activateCursorConnection(email: String?) {
        isCursorConnected = true
        cursorEmail = email
        cursorConnectionError = nil
        scheduleTimer()
        refresh(manual: false)
    }

    private static func isTokenExpired(_ token: String) -> Bool {
        guard let exp = CursorUsageClient.tokenExpiry(token) else { return false }
        return exp < Date()
    }

    private func setCursorConnectionEnabled(_ enabled: Bool) {
        var cfg = config
        cfg.cursorConnectionEnabled = enabled
        config = cfg
        cfg.save()
    }

    private func saveCursorEmail(_ email: String?) {
        var cfg = config
        cfg.cursorStoredEmail = email
        config = cfg
        cfg.save()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = max(PollIntervalUnit.minimumPollMinutes, config.pollIntervalMinutes) * 60
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh(manual: false)
        }
        t.tolerance = interval * 0.1
        timer = t
    }

    // MARK: - Refresh

    func refresh(manual: Bool = true) {
        guard isCursorConnected else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        if manual {
            ActivityJournal.shared.logAction(JournalLog.pollUsage, detail: JournalLog.pollManual)
        }
        CursorUsageClient.fetch { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                guard self.isCursorConnected else { return }
                switch result {
                case .success(let snap):
                    self.snapshot = snap
                    self.lastError = nil
                    var updatedState = self.state
                    let alerts = AlertEngine.process(snapshot: snap,
                                                     config: self.config,
                                                     state: &updatedState)
                    self.state = updatedState
                    if !alerts.isEmpty {
                        ActivityJournal.shared.logAction(
                            JournalLog.sendNotifications,
                            detail: JournalLog.notificationCount(alerts.count)
                        )
                    }
                    for a in alerts { Notifier.send(a, config: self.config) }
                case .failure(let err):
                    if case .tokenExpired = err,
                       let fresh = CursorUsageClient.readTokenFromCursor(),
                       !fresh.isEmpty,
                       !Self.isTokenExpired(fresh) {
                        CursorUsageClient.saveToken(fresh)
                        self.saveCursorEmail(CursorUsageClient.cachedEmailFromCursor())
                        self.refresh(manual: false)
                        return
                    }
                    self.lastError = err.description
                }
                self.onChange?()
            }
        }
    }

    // MARK: - Derived

    var spentToday: Double {
        guard let snap = snapshot else { return 0 }
        return AlertEngine.spentToday(snapshot: snap, state: state)
    }

    var effectiveDailyThreshold: Double {
        AlertEngine.effectiveDailyThreshold(
            config: config,
            snapshot: snapshot,
            state: state,
            now: snapshot?.fetchedAt ?? Date()
        )
    }

    /// Percent value shown in the menu-bar title, depending on user preference.
    var menuBarPercent: Double? {
        guard let snap = snapshot else { return nil }
        switch config.resolvedMenuBarPercentMode {
        case .total: return snap.totalPercentUsed
        case .daily:
            return AlertEngine.dailyQuotaUsedPercent(
                spentToday: spentToday,
                dailyQuotaPercent: effectiveDailyThreshold
            )
        }
    }

    /// Whether the menu-bar title should show a warning mark.
    var isWarning: Bool {
        effectiveDailyThreshold > 0 && spentToday >= effectiveDailyThreshold
    }

    // MARK: - Config

    /// Persists an edited config. The Telegram bot token goes to `secrets.json`
    /// (empty clears it) and never into `config.json`.
    func applyConfig(_ edited: Config) {
        let previous = config
        SecretStore.set(edited.telegram.botToken, account: Config.telegramSecretAccount)
        var cfg = edited
        if cfg.telegram.enabled, cfg.telegram.botToken.isEmpty {
            cfg.telegram.botToken = SecretStore.get(Config.telegramSecretAccount) ?? ""
        }
        cfg.telegram.botToken = cfg.telegram.enabled ? cfg.telegram.botToken : ""
        config = cfg
        config.save()
        cfg.resolvedAppTheme.apply()
        syncLanguage(from: cfg, previous: previous.resolvedAppLanguage)
        ActivityJournal.shared.setLoggingEnabled(cfg.resolvedJournalLoggingEnabled)
        scheduleConfigLog(for: cfg)
        if isCursorConnected, previous.pollIntervalMinutes != cfg.pollIntervalMinutes {
            scheduleTimer()
            refresh(manual: false)
        }
        onChange?()
    }

    func reloadConfig() {
        let previous = config
        config = Config.load()
        config.resolvedAppTheme.apply()
        syncLanguage(from: config, previous: previous.resolvedAppLanguage)
        ActivityJournal.shared.setLoggingEnabled(config.resolvedJournalLoggingEnabled)
        if isCursorConnected, previous.pollIntervalMinutes != config.pollIntervalMinutes {
            scheduleTimer()
            refresh(manual: false)
        }
        onChange?()
    }

    func sendTestMacNotification() {
        ActivityJournal.shared.logAction(JournalLog.testMac)
        Notifier.macNotification(title: L10n.testNotificationTitle, body: testNotificationBody())
    }

    func sendTestTelegramNotification(completion: ((Bool, String) -> Void)? = nil) {
        ActivityJournal.shared.logAction(JournalLog.testTelegram)
        let tg = config.telegram
        guard !tg.botToken.isEmpty, !tg.chatId.isEmpty else {
            completion?(false, L10n.testTelegramMissingCredentials)
            return
        }
        Notifier.telegram("\(L10n.testNotificationTitle): \(testNotificationBody())", config: tg, completion: completion)
    }

    private func testNotificationBody() -> String {
        L10n.testNotificationBodyPrefix
            + (snapshot.map { L10n.testNotificationQuota(AlertEngine.fmt($0.totalPercentUsed)) } ?? "")
    }

    private func scheduleConfigLog(for edited: Config) {
        configLogWorkItem?.cancel()
        let work = DispatchWorkItem {
            ActivityJournal.shared.logAction(
                JournalLog.saveSettings,
                detail: JournalLog.configChangeSummary(from: edited)
            )
        }
        configLogWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func applyLanguage(from config: Config) {
        L10n.languageCode = config.resolvedAppLanguage.localeIdentifier
    }

    private func syncLanguage(from config: Config, previous: AppLanguage) {
        applyLanguage(from: config)
        if previous != config.resolvedAppLanguage {
            uiLocaleRevision = UUID()
        }
    }
}
