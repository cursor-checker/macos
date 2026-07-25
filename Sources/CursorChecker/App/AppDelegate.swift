import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let model = AppModel()

    private var settingsWindow: NSWindow?
    private var isMenuOpen = false
    private var pendingMenuRebuild = false
    private var menuShowsConnectedState = false
    private var quitEventMonitor: Any?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.requestCloseSettingsSheets()
        settingsWindow?.close()
        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installQuitShortcutMonitor()

        LaunchAtLogin.migrateLaunchAgentIfNeeded()
        AppIcon.install()
        Notifier.configureMacNotifications { [weak self] in
            self?.showOverview()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Cursor …"

        model.onChange = { [weak self] in
            guard let self = self else { return }
            self.installMainMenu()
            self.settingsWindow?.title = L10n.commonSettings
            self.updateStatusItem()
            if self.isMenuOpen {
                if self.menuShowsConnectedState != self.model.isCursorConnected {
                    self.rebuildMenu()
                } else {
                    self.pendingMenuRebuild = true
                    self.updateOpenMenuItems()
                }
            } else {
                self.rebuildMenu()
            }
        }

        rebuildMenu()
        updateStatusItem()
        model.start()
    }

    // MARK: - Status item

    private func updateStatusItem() {
        statusItem.isVisible = model.config.resolvedMenuBarVisible
        guard statusItem.isVisible, let button = statusItem.button else { return }

        button.image = nil

        guard model.isCursorConnected else {
            button.title = "Cursor —"
            return
        }

        guard model.snapshot != nil else {
            button.title = model.lastError != nil ? "Cursor ⚠️" : "Cursor …"
            return
        }
        let mark = model.config.resolvedMenuBarWarningIconEnabled && model.isWarning ? "⚠️ " : ""
        let value = model.menuBarPercent ?? 0
        button.title = String(format: "%@%.0f%%", mark, value)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        appendInfoLines(to: menu, lines: menuInfoLines())

        if !model.isCursorConnected {
            add(menu, L10n.appMenuConnectCursor, #selector(showConnectionSettings))
        }

        if menu.items.contains(where: { !$0.isSeparatorItem }) {
            menu.addItem(.separator())
        }
        if let updatedLine = menuUpdatedAtLine() {
            addInfo(menu, updatedLine, tag: Self.updatedAtMenuItemTag)
        }
        add(menu, L10n.commonRefreshNow, #selector(refreshNow), enabled: refreshMenuItemEnabled)
        menu.addItem(.separator())
        add(menu, L10n.commonOverview, #selector(showOverview))
        add(menu, L10n.commonSettings, #selector(showSettings))

        menu.addItem(.separator())
        add(menu, L10n.commonQuit, #selector(quit))

        statusItem.menu = menu
        menuShowsConnectedState = model.isCursorConnected
    }

    private func menuInfoLines() -> [String] {
        let fields = model.config.resolvedMenuPopupFields

        if !model.isCursorConnected {
            return [L10n.appMenuCursorNotConnected]
        }
        if let snap = model.snapshot {
            return fields.resolvedFieldOrder.compactMap { menuInfoLine(for: $0, fields: fields, snap: snap) }
        }
        if let err = model.lastError {
            return [L10n.appMenuError(err)]
        }
        return [L10n.commonLoading]
    }

    private func menuInfoLine(for field: MenuPopupField, fields: MenuPopupFields, snap: UsageSnapshot) -> String? {
        guard fields.isEnabled(field) else { return nil }
        switch field {
        case .today:
            return L10n.appMenuTodayLine(
                AlertEngine.fmt(model.spentToday),
                AlertEngine.fmt(model.effectiveDailyThreshold)
            )
        case .totalSpent:
            return L10n.appMenuTotalSpentLine(AlertEngine.fmt(snap.totalPercentUsed))
        case .remaining:
            return L10n.appMenuRemainingLine(AlertEngine.fmt(snap.remainingPercent))
        case .autoApi:
            return "  auto \(AlertEngine.fmt(snap.autoPercentUsed))% · api \(AlertEngine.fmt(snap.apiPercentUsed))%"
        case .spendUSD:
            return L10n.appMenuSpendUSDLine(AlertEngine.fmt(snap.totalSpendUSD))
        case .cycleEnd:
            guard snap.cycleEndMs > 0 else { return nil }
            return snap.cycleResetMenuLine()
        }
    }

    private func menuUpdatedAtLine() -> String? {
        guard model.isCursorConnected, let snap = model.snapshot else { return nil }
        return L10n.appMenuUpdatedLine(timeString(snap.fetchedAt))
    }

    private func appendInfoLines(to menu: NSMenu, lines: [String]) {
        for line in lines {
            addInfo(menu, line)
        }
    }

    private func showStatusMenu() {
        if isMenuOpen {
            updateOpenMenuItems()
        } else if let menu = statusItem.menu, !menuNeedsRebuild(from: menu) {
            updateOpenMenuItems()
        } else {
            rebuildMenu()
        }
        guard let menu = statusItem.menu else { return }

        NSApp.activate(ignoringOtherApps: true)

        if statusItem.isVisible, let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: 0), in: button)
        } else if let screen = NSScreen.main {
            let point = NSPoint(x: screen.frame.midX, y: screen.frame.minY + 4)
            menu.popUp(positioning: nil, at: point, in: nil)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    private func updateOpenMenuItems() {
        guard let menu = statusItem.menu else { return }
        let lines = menuInfoLines()
        let infoItems = menu.items.filter { $0.tag == Self.infoMenuItemTag }
        for (item, line) in zip(infoItems, lines) {
            (item.view as? InfoMenuItemView)?.updateText(line)
        }
        for item in menu.items where item.action == #selector(refreshNow) {
            item.isEnabled = refreshMenuItemEnabled
        }
        if let updatedLine = menuUpdatedAtLine(),
           let item = menu.items.first(where: { $0.tag == Self.updatedAtMenuItemTag }) {
            (item.view as? InfoMenuItemView)?.updateText(updatedLine)
        }
    }

    private var refreshMenuItemEnabled: Bool {
        model.isCursorConnected && !model.isRefreshing
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        updateOpenMenuItems()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        if pendingMenuRebuild {
            pendingMenuRebuild = false
            if menuNeedsRebuild(from: menu) {
                rebuildMenu()
            }
        }
    }

    private func menuNeedsRebuild(from menu: NSMenu) -> Bool {
        if menuShowsConnectedState != model.isCursorConnected { return true }
        let infoCount = menu.items.filter { $0.tag == Self.infoMenuItemTag }.count
        let hasUpdatedItem = menu.items.contains { $0.tag == Self.updatedAtMenuItemTag }
        let wantsUpdatedItem = menuUpdatedAtLine() != nil
        if hasUpdatedItem != wantsUpdatedItem { return true }
        return infoCount != menuInfoLines().count
    }

    private static let infoMenuItemTag = 100
    private static let updatedAtMenuItemTag = 101

    private func addInfo(_ menu: NSMenu, _ text: String, tag: Int = infoMenuItemTag) {
        let item = NSMenuItem()
        item.tag = tag
        item.view = InfoMenuItemView(text: text)
        menu.addItem(item)
    }

    private func add(_ menu: NSMenu, _ title: String, _ sel: Selector, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func refreshNow() {
        guard refreshMenuItemEnabled else { return }
        model.refresh()
    }

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(refreshNow) {
            return refreshMenuItemEnabled
        }
        return true
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func installMainMenu() {
        let appName = AppInfo.displayName
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: L10n.appMenuAbout(appName),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.appMenuHide(appName),
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: L10n.appMenuHideOthers,
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: L10n.appMenuShowAll,
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.appMenuQuit(appName),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        NSApp.mainMenu = mainMenu
    }

    private func installQuitShortcutMonitor() {
        quitEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command),
                  event.charactersIgnoringModifiers?.lowercased() == "q" else {
                return event
            }
            NSApp.terminate(nil)
            return nil
        }
    }

    @objc private func showOverview() { openSettings(tab: .overview) }

    @objc private func showConnectionSettings() { openSettings(tab: .connection) }

    @objc private func showSettings() { openSettings(tab: .basics) }

    private func openSettings(tab: SettingsTab? = nil) {
        if let tab {
            model.settingsTab = tab
        }
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(model: model))
            let w = makeWindow(host, title: L10n.commonSettings, resizable: true)
            configureSettingsWindow(w)
            settingsWindow = w
        }
        present(settingsWindow!)
    }

    // MARK: - Windows

    /// Settings uses a custom SwiftUI toolbar for section titles. Hide the window
    /// title so Xcode 27 does not paint «Настройки» over the detail column.
    private func configureSettingsWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = .textBackgroundColor

        let width = SettingsLayout.windowWidth
        window.setContentSize(NSSize(width: width, height: 570))
        window.contentMinSize = NSSize(width: width, height: SettingsLayout.windowMinHeight)
        window.contentMaxSize = NSSize(width: width, height: 4000)
        window.center()
    }

    private func makeWindow(_ controller: NSViewController, title: String,
                            resizable: Bool = false) -> NSWindow {
        let w = NSWindow(contentViewController: controller)
        w.title = title
        var mask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { mask.insert(.resizable) }
        w.styleMask = mask
        w.isReleasedWhenClosed = false
        w.delegate = self
        return w
    }

    private func present(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window === settingsWindow {
            DockIcon.setPreferredVisible(true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        model.resetSettingsNavigation()
        DockIcon.setPreferredVisible(false)
    }

    // MARK: - Formatting

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: date)
    }
}

private final class InfoMenuItemView: NSView {
    private let label = NSTextField(labelWithString: "")

    override var allowsVibrancy: Bool { false }

    init(text: String) {
        super.init(frame: .zero)
        label.font = .menuFont(ofSize: 0)
        label.textColor = .controlTextColor
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        updateText(text)
    }

    required init?(coder: NSCoder) { nil }

    func updateText(_ text: String) {
        label.stringValue = text
        let font = NSFont.menuFont(ofSize: 0)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        let width = ceil(textWidth) + 32
        frame = NSRect(x: 0, y: 0, width: width, height: 22)
    }
}
