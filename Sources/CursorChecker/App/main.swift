import AppKit

// `--dump-resources`: print bundle/resource resolution (for debugging builds).
if CommandLine.arguments.contains("--dump-resources") {
    print("bundlePath:", Bundle.main.bundlePath)
    print("resourceURL:", Bundle.main.resourceURL?.path ?? "nil")
    print("resolved CHANGELOG:", AppResources.url(forResource: "CHANGELOG", withExtension: "md")?.path ?? "nil")
    print("entries:", Changelog.entries.count)
    exit(0)
}

// `--test`: send a test notification to every enabled channel, then exit.
if CommandLine.arguments.contains("--test") {
    AppIcon.install()
    let config = Config.load()
    print("mac notifications: \(config.macNotificationsEnabled ? "on" : "off"), " +
          "telegram: \(config.telegram.enabled ? "on" : "off")")
    Notifier.configureMacNotifications(onTap: {})
    let sema = DispatchSemaphore(value: 0)
    var pending = 0
    if config.macNotificationsEnabled {
        pending += 1
        Notifier.requestMacAuthorization { _ in
            Notifier.macNotification(title: "Cursor Checker", body: "Тест macOS-уведомления")
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { sema.signal() }
        }
    }
    if config.telegram.enabled, !config.telegram.botToken.isEmpty, !config.telegram.chatId.isEmpty {
        pending += 1
        Notifier.telegram("Cursor Checker: тест Telegram-уведомления", config: config.telegram) { ok, msg in
            print("telegram: \(ok ? "OK" : "FAILED") — \(msg)")
            sema.signal()
        }
    } else {
        print("telegram: skipped (disabled or not configured)")
    }
    for _ in 0..<pending { sema.wait() }
    exit(0)
}

// `--once`: fetch a single snapshot, print it, fire any alerts, then exit.
// Useful for smoke tests and for running from cron instead of the menu-bar app.
if CommandLine.arguments.contains("--once") {
    AppIcon.install()
    Notifier.configureMacNotifications(onTap: {})
    let config = Config.load()
    var state = UsageState.load()
    let sema = DispatchSemaphore(value: 0)

    CursorUsageClient.fetch { result in
        switch result {
        case .success(let snap):
            let today = AlertEngine.spentToday(snapshot: snap, state: state)
            print("total: \(AlertEngine.fmt(snap.totalPercentUsed))%  " +
                  "today: +\(AlertEngine.fmt(today))%  " +
                  "auto: \(AlertEngine.fmt(snap.autoPercentUsed))%  " +
                  "api: \(AlertEngine.fmt(snap.apiPercentUsed))%  " +
                  "spend: $\(AlertEngine.fmt(snap.totalSpendUSD))")
            let alerts = AlertEngine.process(snapshot: snap, config: config, state: &state)
            for a in alerts {
                print("ALERT: \(a.title) — \(a.body)")
                Notifier.send(a, config: config)
            }
            if alerts.isEmpty { print("no alerts") }
        case .failure(let err):
            FileHandle.standardError.write(Data(("error: \(err.description)\n").utf8))
        }
        // give async notifications a moment to flush
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { sema.signal() }
    }
    sema.wait()
    exit(0)
}

let app = NSApplication.shared
SingleInstance.exitIfAnotherInstanceIsRunning()
let delegate = AppDelegate()
app.delegate = delegate
DockIcon.setPreferredVisible(false)
app.run()
