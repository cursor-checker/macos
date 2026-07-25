import Foundation

enum L10n {
    /// `nil` follows the system language (ru/en).
    static var languageCode: String?

    private static var bundle: Bundle { AppResources.localizationBundle }

    static var resolvedLanguageCode: String { activeLanguageCode }

    private static var activeLanguageCode: String {
        if let languageCode { return languageCode }
        let preferred = Locale.preferredLanguages.first ?? "ru"
        return preferred.hasPrefix("en") ? "en" : "ru"
    }

    private static func localizedBundle(for languageCode: String) -> Bundle {
        guard let path = bundle.path(forResource: languageCode, ofType: "lproj"),
              let langBundle = Bundle(path: path) else {
            return bundle
        }
        return langBundle
    }

    private static func tr(_ key: String) -> String {
        localizedBundle(for: activeLanguageCode)
            .localizedString(forKey: key, value: key, table: "Localizable")
    }

    private static func tr(_ key: String, _ args: CVarArg...) -> String {
        String(format: tr(key), locale: Locale(identifier: activeLanguageCode), arguments: args)
    }

    // MARK: - Settings tabs

    static var settingsTabOverview: String { tr("settings.tab.overview") }
    static var settingsTabConnection: String { tr("settings.tab.connection") }
    static var settingsTabBasics: String { tr("settings.tab.basics") }
    static var settingsTabGeneral: String { tr("settings.tab.general") }
    static var settingsTabMenuBar: String { tr("settings.tab.menuBar") }
    static var settingsTabNotifications: String { tr("settings.tab.notifications") }
    static var settingsTabJournal: String { tr("settings.tab.journal") }
    static var settingsTabAbout: String { tr("settings.tab.about") }
    static var settingsNavBack: String { tr("settings.nav.back") }
    static var settingsNavForward: String { tr("settings.nav.forward") }

    // MARK: - Config enums

    static var pollUnitSeconds: String { tr("poll.unit.seconds") }
    static var pollUnitMinutes: String { tr("poll.unit.minutes") }
    static var pollUnitHours: String { tr("poll.unit.hours") }

    static var menuBarModeTotal: String { tr("menuBar.mode.total") }
    static var menuBarModeDaily: String { tr("menuBar.mode.daily") }

    static var menuFieldToday: String { tr("menuField.today") }
    static var menuFieldTotalSpent: String { tr("menuField.totalSpent") }
    static var menuFieldRemaining: String { tr("menuField.remaining") }
    static var menuFieldSpendUSD: String { tr("menuField.spendUSD") }
    static var menuFieldCycleEnd: String { tr("menuField.cycleEnd") }
    static var menuFieldAutoApi: String { tr("menuField.autoApi") }

    static var updateChannelStable: String { tr("updateChannel.stable") }
    static var updateChannelBeta: String { tr("updateChannel.beta") }

    static var appThemeSystem: String { tr("appTheme.system") }
    static var appThemeLight: String { tr("appTheme.light") }
    static var appThemeDark: String { tr("appTheme.dark") }

    // MARK: - Common

    static var commonShow: String { tr("common.show") }
    static var commonClose: String { tr("common.close") }
    static var commonDelete: String { tr("common.delete") }
    static var commonCancel: String { tr("common.cancel") }
    static var commonSend: String { tr("common.send") }
    static var commonCheck: String { tr("common.check") }
    static var commonUpdate: String { tr("common.update") }
    static var commonDetails: String { tr("common.details") }
    static var commonClear: String { tr("common.clear") }
    static var commonRequest: String { tr("common.request") }
    static var commonSettingsEllipsis: String { tr("common.settingsEllipsis") }
    static var commonConnected: String { tr("common.connected") }
    static var commonAllowed: String { tr("common.allowed") }
    static var commonLoading: String { tr("common.loading") }
    static var commonChecking: String { tr("common.checking") }
    static var commonRefresh: String { tr("common.refresh") }
    static var commonRefreshNow: String { tr("common.refreshNow") }
    static var commonQuit: String { tr("common.quit") }
    static var commonOverview: String { tr("common.overview") }
    static var commonSettings: String { tr("common.settings") }
    static var commonToday: String { tr("common.today") }
    static var commonRemaining: String { tr("common.remaining") }
    static var commonUpdated: String { tr("common.updated") }
    static var commonTotalSpent: String { tr("common.totalSpent") }
    static func thresholdValue(_ value: String) -> String { tr("common.thresholdValue", value) }
    static func commonError(_ message: String) -> String { tr("common.errorPrefix", message) }

    // MARK: - Basics

    static var basicsAppearance: String { tr("basics.appearance") }
    static var basicsLanguage: String { tr("basics.language") }
    static var appLanguageSystem: String { tr("appLanguage.system") }
    static var basicsLaunchAtLogin: String { tr("basics.launchAtLogin") }
    static var basicsLaunchAtLoginEnabled: String { tr("basics.launchAtLoginEnabled") }
    static var basicsLaunchAtLoginDisabled: String { tr("basics.launchAtLoginDisabled") }

    // MARK: - Connection

    static var connectionAccess: String { tr("connection.access") }
    static var connectionAccount: String { tr("connection.account") }
    static var connectionHowItWorks: String { tr("connection.howItWorks") }
    static var connectionHowItWorksBody: String { tr("connection.howItWorksBody") }
    static var connectionChecking: String { tr("connection.checking") }
    static var connectionActive: String { tr("connection.active") }
    static var connectionPrompt: String { tr("connection.prompt") }
    static var connectionGetToken: String { tr("connection.getToken") }
    static var connectionRevokeToken: String { tr("connection.revokeToken") }

    // MARK: - General

    static var generalPollInterval: String { tr("general.pollInterval") }
    static var generalPollBatteryHint: String { tr("general.pollBatteryHint") }
    static var generalTimeUnit: String { tr("general.timeUnit") }
    static var generalInterval: String { tr("general.interval") }
    static var generalDailyThreshold: String { tr("general.dailyThreshold") }
    static var generalDailyThresholdHint: String { tr("general.dailyThresholdHint") }
    static var generalDailyThresholdSmartHint: String { tr("general.dailyThresholdSmartHint") }
    static var generalDailyThresholdSmartMode: String { tr("general.dailyThresholdSmartMode") }
    static var generalDailyThresholdSmartModeHint: String { tr("general.dailyThresholdSmartModeHint") }
    static var generalDailyThresholdWorkingDays: String { tr("general.dailyThresholdWorkingDays") }
    static var generalDailyThresholdWorkingDaysHint: String { tr("general.dailyThresholdWorkingDaysHint") }
    static var generalDailyThresholdManualHint: String { tr("general.dailyThresholdManualHint") }
    static func generalDailyThresholdSmartPreview(_ remaining: String, _ days: Int, _ workingDaysOnly: Bool) -> String {
        tr("general.dailyThresholdSmartPreview", remaining, days, workingDaysOnly ? tr("general.dailyThresholdDaysWorking") : tr("general.dailyThresholdDaysAll"))
    }
    static var generalThreshold: String { tr("general.threshold") }

    // MARK: - Menu bar settings

    static var menuBarShowInMenuBar: String { tr("menuBar.showInMenuBar") }
    static var menuBarShowInMenuBarHint: String { tr("menuBar.showInMenuBarHint") }
    static var menuBarTitle: String { tr("menuBar.title") }
    static var menuBarTitleHint: String { tr("menuBar.titleHint") }
    static var menuBarWarningIcon: String { tr("menuBar.warningIcon") }
    static var menuBarWarningIconHint: String { tr("menuBar.warningIconHint") }
    static var menuBarDropdown: String { tr("menuBar.dropdown") }
    static var menuBarReorderHint: String { tr("menuBar.reorderHint") }
    static var menuBarReorderAccessibility: String { tr("menuBar.reorderAccessibility") }

    // MARK: - Notifications

    static var notificationsMac: String { tr("notifications.mac") }
    static var notificationsMacPermission: String { tr("notifications.macPermission") }
    static var notificationsTest: String { tr("notifications.test") }
    static var notificationsEnableMacFirst: String { tr("notifications.enableMacFirst") }
    static var notificationsMacAuthorized: String { tr("notifications.macAuthorized") }
    static var notificationsMacDenied: String { tr("notifications.macDenied") }
    static var notificationsMacNotRequested: String { tr("notifications.macNotRequested") }
    static var notificationsMacTestHint: String { tr("notifications.macTestHint") }
    static var notificationsMacTestNeedsPermission: String { tr("notifications.macTestNeedsPermission") }
    static var notificationsTelegramEnable: String { tr("notifications.telegramEnable") }
    static var notificationsBotToken: String { tr("notifications.botToken") }
    static var notificationsChatId: String { tr("notifications.chatId") }
    static var notificationsChatIdPlaceholder: String { tr("notifications.chatIdPlaceholder") }
    static var notificationsTelegramTestHint: String { tr("notifications.telegramTestHint") }
    static var notificationsPermissionAlertTitle: String { tr("notifications.permissionAlertTitle") }
    static var notificationsPermissionAlertBody: String { tr("notifications.permissionAlertBody") }
    static var notificationsOpenSettings: String { tr("notifications.openSettings") }
    static var notificationsTelegramSection: String { tr("notifications.telegramSection") }

    // MARK: - Journal

    static var journalEnable: String { tr("journal.enable") }
    static var journalEnabledHint: String { tr("journal.enabledHint") }
    static var journalDisabledHint: String { tr("journal.disabledHint") }
    static var journalClear: String { tr("journal.clear") }
    static var journalClearHelp: String { tr("journal.clearHelp") }
    static var journalLoggingDisabled: String { tr("journal.loggingDisabled") }
    static var journalEmptyPlaceholder: String { tr("journal.emptyPlaceholder") }
    static var journalActionFailed: String { tr("journal.actionFailed") }

    // MARK: - About (excluding changelog / license)

    static var aboutTagline: String { tr("about.tagline") }
    static func aboutVersion(_ label: String) -> String { tr("about.version", label) }
    static var aboutUpdateChannel: String { tr("about.updateChannel") }
    static var aboutUpdateCheck: String { tr("about.updateCheck") }
    static var aboutDeleteApp: String { tr("about.deleteApp") }
    static var aboutCheckingGitHub: String { tr("about.checkingGitHub") }
    static func aboutUpToDateStable(_ version: String) -> String { tr("about.upToDateStable", version) }
    static func aboutUpToDateBeta(_ version: String) -> String { tr("about.upToDateBeta", version) }
    static func aboutUpdateAvailableStable(_ version: String) -> String { tr("about.updateAvailableStable", version) }
    static func aboutUpdateAvailableBeta(_ version: String) -> String { tr("about.updateAvailableBeta", version) }
    static var aboutNoStableReleases: String { tr("about.noStableReleases") }
    static var aboutNoBetaReleases: String { tr("about.noBetaReleases") }
    static var aboutDownloading: String { tr("about.downloading") }
    static var aboutInstalling: String { tr("about.installing") }
    static var aboutChangelog: String { tr("about.changelog") }
    static func aboutWhatsNewIn(_ version: String) -> String { tr("about.whatsNewIn", version) }
    static var aboutUpdateNotesSubtitle: String { tr("about.updateNotesSubtitle") }

    // MARK: - License / changelog panels

    static var licenseTitle: String { tr("license.title") }
    static var licenseNotFound: String { tr("license.notFound") }
    static var changelogEmpty: String { tr("changelog.empty") }
    static var changelogUnavailable: String { tr("changelog.unavailable") }
    static func changelogVersion(_ version: String) -> String { tr("changelog.version", version) }

    // MARK: - Overview

    static var overviewDisconnectedTitle: String { tr("overview.disconnectedTitle") }
    static var overviewDisconnectedBody: String { tr("overview.disconnectedBody") }
    static var overviewBreakdownAutoCaption: String { tr("overview.breakdownAutoCaption") }
    static var overviewBreakdownAPICaption: String { tr("overview.breakdownAPICaption") }
    static func overviewBreakdownSummary(_ auto: String, _ api: String) -> String {
        tr("overview.breakdownSummary", auto, api)
    }
    static var overviewBreakdownAutoTitle: String { tr("overview.breakdownAutoTitle") }
    static var overviewBreakdownAPITitle: String { tr("overview.breakdownAPITitle") }

    // MARK: - App menu / status menu

    static var appMenuConnectCursor: String { tr("appMenu.connectCursor") }
    static var appMenuCursorNotConnected: String { tr("appMenu.cursorNotConnected") }
    static func appMenuError(_ message: String) -> String { tr("appMenu.error", message) }
    static func appMenuTodayLine(_ spent: String, _ threshold: String) -> String {
        tr("appMenu.todayLine", spent, threshold)
    }
    static func appMenuTotalSpentLine(_ value: String) -> String { tr("appMenu.totalSpentLine", value) }
    static func appMenuRemainingLine(_ value: String) -> String { tr("appMenu.remainingLine", value) }
    static func appMenuSpendUSDLine(_ value: String) -> String { tr("appMenu.spendUSDLine", value) }
    static func appMenuUpdatedLine(_ time: String) -> String { tr("appMenu.updatedLine", time) }
    static func appMenuAbout(_ appName: String) -> String { tr("appMenu.about", appName) }
    static func appMenuHide(_ appName: String) -> String { tr("appMenu.hide", appName) }
    static var appMenuHideOthers: String { tr("appMenu.hideOthers") }
    static var appMenuShowAll: String { tr("appMenu.showAll") }
    static func appMenuQuit(_ appName: String) -> String { tr("appMenu.quit", appName) }

    // MARK: - Cycle / dates

    static var cycleToday: String { tr("cycle.today") }
    static var cycleDayOne: String { tr("cycle.dayOne") }
    static var cycleDayFew: String { tr("cycle.dayFew") }
    static var cycleDayMany: String { tr("cycle.dayMany") }
    static func cycleResetLine(_ date: String, _ days: String) -> String {
        tr("cycle.resetLine", date, days)
    }

    static func daysLabel(_ days: Int) -> String {
        if days == 0 { return cycleToday }
        let n = abs(days)
        let mod10 = n % 10
        let mod100 = n % 100
        let word: String
        if activeLanguageCode == "ru" {
            if mod10 == 1 && mod100 != 11 {
                word = cycleDayOne
            } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
                word = cycleDayFew
            } else {
                word = cycleDayMany
            }
            return "\(n) \(word)"
        }
        return n == 1 ? tr("cycle.daysOne", n) : tr("cycle.daysOther", n)
    }

    // MARK: - Usage errors

    static var errorNoToken: String { tr("error.noToken") }
    static var errorTokenExpired: String { tr("error.tokenExpired") }
    static func errorDecode(_ message: String) -> String { tr("error.decode", message) }
    static func errorNetwork(_ message: String) -> String { tr("error.network", message) }

    // MARK: - Alerts

    static func alertDailyTitle(_ spent: String) -> String { tr("alert.dailyTitle", spent) }
    static func alertDailyBody(_ reached: String, _ step: String, _ total: String) -> String {
        tr("alert.dailyBody", reached, step, total)
    }

    // MARK: - App model / tests

    static var testNotificationTitle: String { tr("testNotification.title") }
    static var testNotificationBodyPrefix: String { tr("testNotification.bodyPrefix") }
    static func testNotificationQuota(_ value: String) -> String { tr("testNotification.quota", value) }
    static var testTelegramMissingCredentials: String { tr("testTelegram.missingCredentials") }

    static var journalConnectCursor: String { tr("journal.connectCursor") }
    static var journalReadLocalToken: String { tr("journal.readLocalToken") }
    static var journalAccessGranted: String { tr("journal.accessGranted") }
    static var journalRevokeToken: String { tr("journal.revokeToken") }
    static var journalPollUsage: String { tr("journal.pollUsage") }
    static var journalPollManual: String { tr("journal.pollManual") }
    static var journalSendNotifications: String { tr("journal.sendNotifications") }
    static func journalNotificationCount(_ count: Int) -> String { tr("journal.notificationCount", count) }
    static var journalTestMac: String { tr("journal.testMac") }
    static var journalTestTelegram: String { tr("journal.testTelegram") }
    static var journalSaveSettings: String { tr("journal.saveSettings") }
    static var journalCheckUpdates: String { tr("journal.checkUpdates") }
    static var journalDownloadUpdate: String { tr("journal.downloadUpdate") }
    static var journalInstallUpdate: String { tr("journal.installUpdate") }
    static var journalUpdateInstalled: String { tr("journal.updateInstalled") }
    static var journalRelaunchApp: String { tr("journal.relaunchApp") }

    static func configSummaryPoll(_ minutes: Int) -> String { tr("configSummary.poll", minutes) }
    static func configSummaryThreshold(_ percent: Int) -> String { tr("configSummary.threshold", percent) }
    static var configSummaryMacOn: String { tr("configSummary.macOn") }
    static var configSummaryMacOff: String { tr("configSummary.macOff") }
    static var configSummaryTelegramOn: String { tr("configSummary.telegramOn") }
    static var configSummaryTelegramOff: String { tr("configSummary.telegramOff") }
    static var configSummaryMenuVisible: String { tr("configSummary.menuVisible") }
    static var configSummaryMenuHidden: String { tr("configSummary.menuHidden") }
    static func configSummaryUpdates(_ channel: String) -> String { tr("configSummary.updates", channel) }

    // MARK: - App update

    static var updateChecksumRequired: String { tr("update.checksumRequired") }
    static var updateFileNotReceived: String { tr("update.fileNotReceived") }
    static var updateArchiveMissing: String { tr("update.archiveMissing") }
    static var updateInvalidServerResponse: String { tr("update.invalidServerResponse") }
    static var updateReleasesNotFound: String { tr("update.releasesNotFound") }
    static func updateServerCode(_ code: Int) -> String { tr("update.serverCode", code) }
    static var updateGitHubParseFailed: String { tr("update.githubParseFailed") }
    static func updateMissingZip(_ name: String) -> String { tr("update.missingZip", name) }
    static var updateChecksumUnavailable: String { tr("update.checksumUnavailable") }

    static var updateErrorUnzipFailed: String { tr("updateError.unzipFailed") }
    static var updateErrorAppNotFound: String { tr("updateError.appNotFound") }
    static var updateErrorChecksumUnavailable: String { tr("updateError.checksumUnavailable") }
    static var updateErrorChecksumInvalid: String { tr("updateError.checksumInvalid") }
    static var updateErrorChecksumMismatch: String { tr("updateError.checksumMismatch") }
    static func updateErrorUnsafePath(_ path: String) -> String { tr("updateError.unsafePath", path) }

    // MARK: - Uninstaller

    static func uninstallTitle(_ appName: String) -> String { tr("uninstall.title", appName) }
    static var uninstallBody: String { tr("uninstall.body") }
    static var uninstallFailed: String { tr("uninstall.failed") }

    // MARK: - Launch at login

    static var launchAtLoginNotBundled: String { tr("launchAtLogin.notBundled") }
}
