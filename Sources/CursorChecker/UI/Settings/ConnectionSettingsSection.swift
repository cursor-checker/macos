import SwiftUI

struct ConnectionSettingsSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            Card {
                SettingsRow(L10n.connectionAccess, subtitle: cursorConnectionSubtitle) {
                    cursorConnectionControl
                }
                if let email = model.cursorEmail, model.isCursorConnected {
                    RowDivider()
                    SettingsRow(L10n.connectionAccount, subtitle: email) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                            .accessibilityLabel(L10n.commonConnected)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SettingsSectionHeader(title: L10n.connectionHowItWorks)
                    .padding(.leading, SettingsLayout.sectionHeaderIndent)
                Card {
                    Text(L10n.connectionHowItWorksBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var cursorConnectionSubtitle: String? {
        if model.isConnectingCursor {
            return L10n.connectionChecking
        }
        if let err = model.cursorConnectionError {
            return err
        }
        if model.isCursorConnected {
            return L10n.connectionActive
        }
        return L10n.connectionPrompt
    }

    @ViewBuilder
    private var cursorConnectionControl: some View {
        if model.isConnectingCursor {
            ProgressView().controlSize(.small)
        } else if model.isCursorConnected {
            Button(L10n.connectionRevokeToken) {
                model.disconnectCursor()
            }
        } else {
            Button(L10n.connectionGetToken) {
                model.connectCursor()
            }
        }
    }
}
