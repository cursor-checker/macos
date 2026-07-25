import SwiftUI

struct BasicSettingsSection: View {
    @Binding var appLanguage: AppLanguage
    @Binding var appTheme: AppTheme
    @Binding var launchAtLogin: Bool
    @Binding var launchAtLoginError: String?

    var body: some View {
        VStack(spacing: 22) {
            Card {
                SettingsRow(L10n.basicsLanguage) {
                    Picker("", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 170, alignment: .trailing)
                }
            }

            Card {
                SettingsRow(L10n.basicsLaunchAtLogin, subtitle: launchAtLoginError) {
                    launchAtLoginControl
                }
            }

            Card {
                HStack(alignment: .top, spacing: 16) {
                    Text(L10n.basicsAppearance)
                        .foregroundStyle(.primary)
                        .padding(.top, 2)
                    Spacer(minLength: 12)
                    AppThemePicker(selection: $appTheme)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var launchAtLoginControl: some View {
        if LaunchAtLogin.isSupported {
            SettingsControls.switchToggle(launchAtLoginBinding)
        } else {
            SettingsControls.switchToggle(.constant(false))
                .disabled(true)
                .opacity(0.45)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                switch LaunchAtLogin.setEnabled(newValue) {
                case .success:
                    launchAtLogin = newValue
                    launchAtLoginError = nil
                    ActivityJournal.shared.logAction(
                        newValue ? JournalLog.launchAtLoginEnabled : JournalLog.launchAtLoginDisabled
                    )
                case .failure(let error):
                    launchAtLogin = LaunchAtLogin.isEnabled
                    launchAtLoginError = error.localizedDescription
                }
            }
        )
    }
}
