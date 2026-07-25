import SwiftUI

struct JournalSettingsSection: View {
    @ObservedObject private var journal = ActivityJournal.shared
    @Binding var journalLoggingEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Card {
                SettingsRow(
                    L10n.journalEnable,
                    subtitle: journalLoggingEnabled
                        ? L10n.journalEnabledHint
                        : L10n.journalDisabledHint
                ) {
                    SettingsControls.switchToggle($journalLoggingEnabled)
                }
            }

            Card {
                ScrollView {
                    Text(journal.logText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(journalLoggingEnabled ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Spacer()
                Button(L10n.journalClear) { journal.clear() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(journal.entries.isEmpty)
                    .help(L10n.journalClearHelp)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
