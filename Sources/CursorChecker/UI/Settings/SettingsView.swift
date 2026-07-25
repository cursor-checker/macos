import SwiftUI

/// Settings window styled after macOS System Settings.
///
/// Layout strategy (stable on Xcode 27 / Swift 6.4):
/// - `HStack` sidebar + detail — no `NavigationView` / `NSSplitView`, so backgrounds
///   and dividers are controlled entirely in SwiftUI.
/// - `SettingsDetailToolbar` — native-looking section title + back/forward; avoids
///   `NavigationStack` first-launch toolbar bugs.
/// - Tab history drives the toolbar navigation buttons.
struct SettingsView: View {
    private enum NavigationEntry: Equatable {
        case tab(SettingsTab)
        case bundledChangelog
        case customChangelog(title: String, entries: [ChangelogEntry])
        case license
    }

    @ObservedObject var model: AppModel

    @State private var selection: SettingsTab
    @State private var navigationHistory: [NavigationEntry]
    @State private var navigationHistoryIndex: Int
    @State private var isApplyingNavigation = false

    @State private var customPollAmount: Double = 5
    @State private var customPollUnit: PollIntervalUnit = .minutes
    @State private var customDailyThreshold: Double = 5
    @State private var dailyThresholdSmartMode = false
    @State private var dailyThresholdWorkingDaysOnly = false
    @State private var macEnabled = true
    @State private var tgEnabled = false
    @State private var botToken = ""
    @State private var chatId = ""
    @State private var menuBarMode = MenuBarPercentMode.total
    @State private var menuBarVisible = true
    @State private var menuBarWarningIconEnabled = true
    @State private var menuPopupFields = MenuPopupFields()
    @State private var journalLoggingEnabled = false
    @State private var updateChannel: UpdateChannel = .stable
    @State private var appTheme = AppTheme.system
    @State private var appLanguage = AppLanguage.system
    @State private var tgTestResult: String?
    @State private var launchAtLogin = false
    @State private var launchAtLoginError: String?

    private let applyDebounceDelay: TimeInterval = 0.5

    @State private var applyDebounceWorkItem: DispatchWorkItem?

    init(model: AppModel) {
        self.model = model
        let tab = model.settingsTab
        _selection = State(initialValue: tab)
        _navigationHistory = State(initialValue: [.tab(tab)])
        _navigationHistoryIndex = State(initialValue: 0)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: SettingsLayout.sidebarWidth)
                .frame(maxHeight: .infinity)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SettingsColors.panelBackground)
                .ignoresSafeArea(.container, edges: .top)
        }
        .frame(minWidth: SettingsLayout.windowWidth, minHeight: SettingsLayout.windowMinHeight)
        .background(SettingsColors.sidebarBackground)
        .onAppear {
            applyNavigationEntry(navigationHistory[navigationHistoryIndex])
            load()
            refreshLaunchAtLogin()
        }
        .id(model.uiLocaleRevision)
        .onChange(of: model.settingsNavigationEpoch) { _, _ in
            resetNavigationHistory()
        }
        .onChange(of: model.settingsTab) { _, tab in
            guard !isApplyingNavigation else { return }
            if case .tab(let current) = navigationHistory[navigationHistoryIndex],
               current == tab,
               !model.showChangelogSheet,
               !model.showLicenseSheet {
                return
            }
            navigateTo(.tab(tab))
        }
        .onChange(of: model.showChangelogSheet) { _, isShowing in
            guard !isApplyingNavigation, isShowing else { return }
            let entry: NavigationEntry = model.changelogSheetUseBundled
                ? .bundledChangelog
                : .customChangelog(
                    title: model.changelogSheetTitle,
                    entries: model.changelogSheetEntries
                )
            recordNavigation(entry)
        }
        .onChange(of: model.showLicenseSheet) { _, isShowing in
            guard !isApplyingNavigation, isShowing else { return }
            recordNavigation(.license)
        }
        .onChange(of: selection) { _, tab in
            guard model.settingsTab != tab else { return }
            model.settingsTab = tab
        }
        .onChange(of: customPollAmount) { applyDebounced() }
        .onChange(of: customPollUnit) { applyDebounced() }
        .onChange(of: customDailyThreshold) { applyDebounced() }
        .onChange(of: dailyThresholdSmartMode) { applyImmediately() }
        .onChange(of: dailyThresholdWorkingDaysOnly) { applyImmediately() }
        .onChange(of: macEnabled) { applyImmediately() }
        .onChange(of: tgEnabled) { _, enabled in
            if !enabled { tgTestResult = nil }
            applyImmediately()
        }
        .onChange(of: botToken) { applyDebounced() }
        .onChange(of: chatId) { applyDebounced() }
        .onChange(of: menuBarMode) { applyImmediately() }
        .onChange(of: menuBarVisible) { applyImmediately() }
        .onChange(of: menuBarWarningIconEnabled) { applyImmediately() }
        .onChange(of: journalLoggingEnabled) { applyImmediately() }
        .onChange(of: updateChannel) { applyImmediately() }
        .onChange(of: appTheme) { applyImmediately() }
        .onChange(of: appLanguage) { applyImmediately() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack(alignment: .top) {
            SettingsColors.sidebarBackground
                .ignoresSafeArea(.container, edges: .top)

            List(selection: sidebarSelection) {
                ForEach(SettingsTab.allCases) { tab in
                    HStack(spacing: 9) {
                        IconBadge(symbol: tab.symbol, color: tab.tint)
                        Text(tab.title)
                    }
                    .padding(.vertical, 2)
                    .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    private var sidebarSelection: Binding<SettingsTab> {
        Binding(
            get: { selection },
            set: { tab in
                if case .tab(let current) = navigationHistory[navigationHistoryIndex],
                   current == tab,
                   model.showChangelogSheet || model.showLicenseSheet {
                    goBack()
                    return
                }
                navigateTo(.tab(tab))
            }
        )
    }

    // MARK: - Detail

    private var detailColumn: some View {
        VStack(spacing: 0) {
            SettingsDetailToolbar(
                title: overlayNavigationTitle,
                canGoBack: navigationHistoryIndex > 0,
                canGoForward: navigationHistoryIndex < navigationHistory.count - 1,
                onBack: goBack,
                onForward: goForward
            )

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var detail: some View {
        ZStack {
            Group {
                if selection == .journal {
                    journalDetail
                } else {
                    scrollDetail
                }
            }
            .background(SettingsColors.panelBackground)

            if model.showChangelogSheet {
                settingsOverlay {
                    ChangelogPanel(
                        title: model.changelogSheetTitle,
                        entries: model.changelogSheetUseBundled ? Changelog.entries : model.changelogSheetEntries,
                        onClose: dismissOverlay
                    )
                }
            } else if model.showLicenseSheet {
                settingsOverlay {
                    LicensePanel(
                        text: AppInfo.licenseText,
                        onClose: dismissOverlay
                    )
                }
            }
        }
    }

    private var overlayNavigationTitle: String {
        switch navigationHistory[navigationHistoryIndex] {
        case .tab(let tab):
            return tab.title
        case .bundledChangelog:
            return L10n.aboutChangelog
        case .customChangelog(let title, _):
            return title
        case .license:
            return L10n.licenseTitle
        }
    }

    private func settingsOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(SettingsColors.panelBackground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scrollDetail: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch selection {
                    case .overview:
                        DetailsView(model: model, embedded: true)
                    case .connection:
                        ConnectionSettingsSection(model: model)
                    case .basics:
                        BasicSettingsSection(
                            appLanguage: $appLanguage,
                            appTheme: $appTheme,
                            launchAtLogin: $launchAtLogin,
                            launchAtLoginError: $launchAtLoginError
                        )
                    case .general:
                        GeneralSettingsSection(
                            model: model,
                            customPollAmount: $customPollAmount,
                            customPollUnit: $customPollUnit,
                            customDailyThreshold: $customDailyThreshold,
                            dailyThresholdSmartMode: $dailyThresholdSmartMode,
                            dailyThresholdWorkingDaysOnly: $dailyThresholdWorkingDaysOnly
                        )
                    case .menuBar:
                        MenuBarSettingsSection(
                            menuBarVisible: $menuBarVisible,
                            menuBarMode: $menuBarMode,
                            menuBarWarningIconEnabled: $menuBarWarningIconEnabled,
                            menuPopupFields: $menuPopupFields,
                            onMenuPopupFieldChange: applyImmediately
                        )
                    case .notifications:
                        NotificationsSettingsSection(
                            model: model,
                            macEnabled: $macEnabled,
                            tgEnabled: $tgEnabled,
                            botToken: $botToken,
                            chatId: $chatId,
                            tgTestResult: $tgTestResult
                        )
                    case .journal:
                        EmptyView()
                    case .about:
                        AboutSettingsSection(
                            model: model,
                            updateChannel: $updateChannel
                        )
                    }
                }
                .padding(24)
                .frame(
                    maxWidth: .infinity,
                    minHeight: selection == .about ? geometry.size.height : nil,
                    alignment: .leading
                )
            }
        }
    }

    private var journalDetail: some View {
        JournalSettingsSection(journalLoggingEnabled: $journalLoggingEnabled)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Navigation history

    private func goBack() {
        guard navigationHistoryIndex > 0 else { return }
        navigationHistoryIndex -= 1
        applyNavigationEntry(navigationHistory[navigationHistoryIndex])
    }

    private func goForward() {
        guard navigationHistoryIndex < navigationHistory.count - 1 else { return }
        navigationHistoryIndex += 1
        applyNavigationEntry(navigationHistory[navigationHistoryIndex])
    }

    private func dismissOverlay() {
        if navigationHistoryIndex > 0 {
            goBack()
        } else {
            model.requestCloseSettingsSheets()
        }
    }

    private func navigateTo(_ entry: NavigationEntry) {
        if case .tab = entry, isOverlayEntry(navigationHistory[navigationHistoryIndex]) {
            navigationHistory.remove(at: navigationHistoryIndex)
            navigationHistoryIndex -= 1
        }
        recordNavigation(entry)
        applyNavigationEntry(entry)
    }

    private func isOverlayEntry(_ entry: NavigationEntry) -> Bool {
        switch entry {
        case .tab: return false
        case .bundledChangelog, .customChangelog, .license: return true
        }
    }

    private func recordNavigation(_ entry: NavigationEntry) {
        if navigationHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((navigationHistoryIndex + 1)...)
        }
        if navigationHistory.last == entry {
            navigationHistoryIndex = navigationHistory.count - 1
            return
        }
        navigationHistory.append(entry)
        navigationHistoryIndex = navigationHistory.count - 1
    }

    private func applyNavigationEntry(_ entry: NavigationEntry) {
        isApplyingNavigation = true

        switch entry {
        case .tab(let tab):
            model.requestCloseSettingsSheets()
            selection = tab
            if model.settingsTab != tab {
                model.settingsTab = tab
            }
        case .bundledChangelog:
            model.showLicenseSheet = false
            model.changelogSheetTitle = L10n.aboutChangelog
            model.changelogSheetUseBundled = true
            model.showChangelogSheet = true
        case .customChangelog(let title, let entries):
            model.showLicenseSheet = false
            model.changelogSheetTitle = title
            model.changelogSheetUseBundled = false
            model.changelogSheetEntries = entries
            model.showChangelogSheet = true
        case .license:
            model.showChangelogSheet = false
            model.showLicenseSheet = true
        }

        DispatchQueue.main.async {
            isApplyingNavigation = false
        }
    }

    private func resetNavigationHistory() {
        let tab = model.settingsTab
        navigationHistory = [.tab(tab)]
        navigationHistoryIndex = 0
        applyNavigationEntry(.tab(tab))
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
        launchAtLoginError = nil
    }

    // MARK: - Config <-> form

    private func applyImmediately() {
        applyDebounceWorkItem?.cancel()
        applyDebounceWorkItem = nil
        model.applyConfig(makeConfig())
    }

    private func applyDebounced() {
        applyDebounceWorkItem?.cancel()
        let work = DispatchWorkItem { model.applyConfig(makeConfig()) }
        applyDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + applyDebounceDelay, execute: work)
    }

    private func load() {
        let c = model.config
        let parts = PollIntervalUnit.decompose(minutes: c.pollIntervalMinutes)
        customPollAmount = parts.amount
        customPollUnit = parts.unit
        customDailyThreshold = c.dailyThresholdPercent
        dailyThresholdSmartMode = c.resolvedDailyThresholdSmartMode
        dailyThresholdWorkingDaysOnly = c.resolvedDailyThresholdWorkingDaysOnly
        macEnabled = c.macNotificationsEnabled
        tgEnabled = c.telegram.enabled
        botToken = c.telegram.botToken
        chatId = c.telegram.chatId
        menuBarMode = c.resolvedMenuBarPercentMode
        menuBarVisible = c.resolvedMenuBarVisible
        menuBarWarningIconEnabled = c.resolvedMenuBarWarningIconEnabled
        menuPopupFields = c.resolvedMenuPopupFields
        journalLoggingEnabled = c.resolvedJournalLoggingEnabled
        updateChannel = c.resolvedUpdateChannel
        appTheme = c.resolvedAppTheme
        appLanguage = c.resolvedAppLanguage
    }

    private func makeConfig() -> Config {
        var c = model.config
        if customPollAmount > 0 {
            let minutes = customPollUnit.toMinutes(customPollAmount)
            c.pollIntervalMinutes = max(PollIntervalUnit.minimumPollMinutes, minutes)
        }
        if customDailyThreshold > 0 {
            c.dailyThresholdPercent = customDailyThreshold
        }
        c.dailyThresholdSmartMode = dailyThresholdSmartMode
        c.dailyThresholdWorkingDaysOnly = dailyThresholdWorkingDaysOnly
        c.macNotificationsEnabled = macEnabled
        c.telegram.enabled = tgEnabled
        c.telegram.botToken = botToken.trimmingCharacters(in: .whitespacesAndNewlines)
        c.telegram.chatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        c.menuBarPercentMode = menuBarMode
        c.menuBarVisible = menuBarVisible
        c.menuBarWarningIconEnabled = menuBarWarningIconEnabled
        c.menuPopupFields = menuPopupFields
        c.journalLoggingEnabled = journalLoggingEnabled
        c.updateChannel = updateChannel
        c.appTheme = appTheme
        c.appLanguage = appLanguage
        return c
    }
}
