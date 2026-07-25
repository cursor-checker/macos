import AppKit
import SwiftUI

struct NotificationsSettingsSection: View {
    @ObservedObject var model: AppModel
    @Binding var macEnabled: Bool
    @Binding var tgEnabled: Bool
    @Binding var botToken: String
    @Binding var chatId: String
    @Binding var tgTestResult: String?

    @State private var macAuthStatus: MacNotificationAuthorizationStatus?

    private var macTestAvailable: Bool { macEnabled && macAuthStatus == .authorized }

    private var macAuthStatusSubtitle: String? {
        guard macEnabled else { return L10n.notificationsEnableMacFirst }
        switch macAuthStatus {
        case .none: return L10n.commonChecking
        case .authorized: return L10n.notificationsMacAuthorized
        case .denied: return L10n.notificationsMacDenied
        case .notDetermined: return L10n.notificationsMacNotRequested
        }
    }

    private var telegramTestAvailable: Bool {
        tgEnabled
            && !botToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var telegramTestSubtitle: String? {
        tgTestResult ?? L10n.notificationsTelegramTestHint
    }

    private var macTestSubtitle: String? {
        guard macEnabled else { return L10n.notificationsEnableMacFirst }
        guard macAuthStatus == .authorized else { return L10n.notificationsMacTestNeedsPermission }
        return L10n.notificationsMacTestHint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Card {
                SettingsRow(L10n.notificationsMac) {
                    SettingsControls.switchToggle($macEnabled)
                }
                RowDivider()
                SettingsRow(L10n.notificationsMacPermission, subtitle: macAuthStatusSubtitle, isEnabled: macEnabled) {
                    macAuthControls
                }
                RowDivider()
                SettingsRow(L10n.notificationsTest, subtitle: macTestSubtitle, isEnabled: macTestAvailable) {
                    Button(L10n.commonSend) {
                        model.sendTestMacNotification()
                    }
                    .settingsButtonEnabled(macTestAvailable)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionHeader(title: L10n.notificationsTelegramSection)
                    .padding(.leading, SettingsLayout.sectionHeaderIndent)
                Card {
                    SettingsRow(L10n.notificationsTelegramEnable) {
                        SettingsControls.switchToggle($tgEnabled)
                    }
                    RowDivider()
                    SettingsRow(L10n.notificationsBotToken, isEnabled: tgEnabled) {
                        SecureField("123456789:AA…", text: $botToken)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            .settingsControlEnabled(tgEnabled)
                    }
                    RowDivider()
                    SettingsRow(L10n.notificationsChatId, isEnabled: tgEnabled) {
                        TextField(L10n.notificationsChatIdPlaceholder, text: $chatId)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                            .settingsControlEnabled(tgEnabled)
                    }
                    RowDivider()
                    SettingsRow(L10n.notificationsTest, subtitle: telegramTestSubtitle, isEnabled: telegramTestAvailable) {
                        Button(L10n.commonSend) {
                            model.sendTestTelegramNotification { ok, msg in
                                DispatchQueue.main.async {
                                    tgTestResult = ok ? nil : L10n.commonError(msg)
                                }
                            }
                        }
                        .settingsButtonEnabled(telegramTestAvailable)
                    }
                }
            }
        }
        .onAppear { refreshMacAuthStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshMacAuthStatus()
        }
        .onChange(of: macEnabled) { _, enabled in
            refreshMacAuthStatus()
            if enabled {
                requestMacPermission()
            }
        }
    }

    @ViewBuilder
    private var macAuthControls: some View {
        switch macAuthStatus {
        case .notDetermined:
            SettingsActionButton(title: L10n.commonRequest, isEnabled: macEnabled) {
                requestMacPermission()
            }
        case .denied:
            SettingsActionButton(title: L10n.commonSettingsEllipsis, isEnabled: macEnabled) {
                Notifier.openMacNotificationSettings()
            }
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
                .accessibilityLabel(L10n.commonAllowed)
        case .none:
            ProgressView().controlSize(.small)
        }
    }

    private func requestMacPermission() {
        guard macEnabled else { return }

        Notifier.requestMacAuthorization { granted in
            refreshMacAuthStatus()
            guard !granted else { return }

            Notifier.macAuthorizationStatus { status in
                if status == .notDetermined {
                    showPermissionHelpAlert()
                }
            }
        }
    }

    private func showPermissionHelpAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.notificationsPermissionAlertTitle
        alert.informativeText = L10n.notificationsPermissionAlertBody
        alert.addButton(withTitle: L10n.notificationsOpenSettings)
        alert.addButton(withTitle: L10n.commonCancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Notifier.openMacNotificationSettings()
    }

    private func refreshMacAuthStatus() {
        Notifier.macAuthorizationStatus { macAuthStatus = $0 }
    }
}
