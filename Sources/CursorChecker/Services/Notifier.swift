import AppKit
import Foundation
import UserNotifications

enum MacNotificationAuthorizationStatus: Equatable {
    case authorized
    case denied
    case notDetermined
}

enum Notifier {

    static func configureMacNotifications(onTap: @escaping () -> Void) {
        mac.onTap = onTap
        mac.install()
    }

    static func requestMacAuthorization(completion: ((Bool) -> Void)? = nil) {
        mac.requestAuthorization(completion: completion)
    }

    static func macAuthorizationStatus(completion: @escaping (MacNotificationAuthorizationStatus) -> Void) {
        mac.authorizationStatus(completion: completion)
    }

    static func openMacNotificationSettings() {
        mac.openSystemSettings()
    }

    static func send(_ alert: Alert, config: Config) {
        if config.macNotificationsEnabled {
            macNotification(title: alert.title, body: alert.body)
        }
        if config.telegram.enabled,
           !config.telegram.botToken.isEmpty,
           !config.telegram.chatId.isEmpty {
            telegram(alert.title + "\n" + alert.body, config: config.telegram)
        }
    }

    // MARK: - macOS banner

    static func macNotification(title: String, body: String) {
        mac.post(title: title, body: body)
    }

    // MARK: - Telegram

    static func telegram(_ text: String, config: TelegramConfig,
                         completion: ((Bool, String) -> Void)? = nil) {
        let urlStr = "https://api.telegram.org/bot\(config.botToken)/sendMessage"
        guard let url = URL(string: urlStr) else {
            completion?(false, "bad url"); return
        }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "chat_id": config.chatId,
            "text": text,
            "disable_web_page_preview": true
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let started = Date()
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let duration = Date().timeIntervalSince(started)
            let endpoint = "https://api.telegram.org/bot***/sendMessage"
            if let err = err {
                ActivityJournal.shared.logRequest(
                    endpoint: endpoint,
                    method: "POST",
                    duration: duration,
                    error: err.localizedDescription
                )
                completion?(false, err.localizedDescription); return
            }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            ActivityJournal.shared.logRequest(
                endpoint: endpoint,
                method: "POST",
                statusCode: code == -1 ? nil : code,
                duration: duration,
                error: (200..<300).contains(code) ? nil : "HTTP \(code)"
            )
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            completion?((200..<300).contains(code), "HTTP \(code): \(body.prefix(300))")
        }.resume()
    }

    private static let mac = MacNotifier()
}

// MARK: - Native macOS notifications

private final class MacNotifier: NSObject, UNUserNotificationCenterDelegate {

    var onTap: (() -> Void)?
    private var installed = false
    /// UNUserNotificationCenter requires a registered .app bundle; Xcode Run on an
    /// SPM executable launches a bare binary from Build/Products/Debug/.
    private let canUseNotifications = Bundle.main.bundlePath.hasSuffix(".app")

    func install() {
        guard !installed else { return }
        installed = true
        guard canUseNotifications else {
            NSLog(
                "CursorChecker: macOS notifications require a .app bundle " +
                "(use swift run CursorChecker or install a release .app)"
            )
            return
        }
        UNUserNotificationCenter.current().delegate = self
        registerWithSystem()
    }

    private func registerWithSystem() {
        if #available(macOS 14.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error {
                    NSLog("CursorChecker: notification registration failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        install()
        guard canUseNotifications else {
            completion?(false)
            return
        }
        let run = {
            DockIcon.beginPromotion()
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: \.isVisible)?.makeKeyAndOrderFront(nil)
            NSApp.requestUserAttention(.informationalRequest)

            // Defer until the app is foreground; background requests are ignored by macOS.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if let error {
                            NSLog("CursorChecker: notification authorization failed: \(error.localizedDescription)")
                        }
                        self.registerWithSystem()
                        DispatchQueue.main.async {
                            DockIcon.endPromotion()
                            completion?(granted)
                        }
                    }
            }
        }
        if Thread.isMainThread {
            run()
        } else {
            DispatchQueue.main.async(execute: run)
        }
    }

    func authorizationStatus(completion: @escaping (MacNotificationAuthorizationStatus) -> Void) {
        install()
        guard canUseNotifications else {
            completion(.notDetermined)
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status: MacNotificationAuthorizationStatus
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                status = .authorized
            case .denied:
                status = .denied
            case .notDetermined:
                status = .notDetermined
            @unknown default:
                status = .denied
            }
            DispatchQueue.main.async { completion(status) }
        }
    }

    func openSystemSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let bundleId = AppInfo.bundleIdentifier
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)",
            "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleId)",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for urlString in candidates {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func post(title: String, body: String) {
        install()
        guard canUseNotifications else { return }
        let deliver = {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                deliver()
            case .notDetermined:
                self.requestAuthorization { granted in
                    if granted { deliver() }
                }
            default:
                break
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                self?.onTap?()
            }
        }
        completionHandler()
    }
}
