import SwiftUI

struct GeneralSettingsSection: View {
    @ObservedObject var model: AppModel
    @Binding var customPollAmount: Double
    @Binding var customPollUnit: PollIntervalUnit
    @Binding var customDailyThreshold: Double
    @Binding var dailyThresholdSmartMode: Bool
    @Binding var dailyThresholdWorkingDaysOnly: Bool

    var body: some View {
        VStack(spacing: 22) {
            pollIntervalGroup
            dailyThresholdGroup
        }
    }

    private var pollIntervalGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: L10n.generalPollInterval)
                .padding(.leading, SettingsLayout.sectionHeaderIndent)
            Text(L10n.generalPollBatteryHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, SettingsLayout.sectionHeaderIndent)
            Card {
                SettingsRow(L10n.generalTimeUnit) {
                    Picker("", selection: $customPollUnit) {
                        ForEach(PollIntervalUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 170, alignment: .trailing)
                }
                RowDivider()
                SettingsRow(L10n.generalInterval) {
                    SettingsControls.numberField($customPollAmount, integersOnly: true)
                }
            }
        }
    }

    private var dailyThresholdGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionHeader(title: L10n.generalDailyThreshold)
                .padding(.leading, SettingsLayout.sectionHeaderIndent)
            Text(L10n.generalDailyThresholdHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, SettingsLayout.sectionHeaderIndent)
            Card {
                SettingsRow(
                    L10n.generalThreshold,
                    subtitle: thresholdPreview
                ) {
                    HStack(spacing: 6) {
                        if dailyThresholdSmartMode {
                            Text("\(AlertEngine.fmt(model.effectiveDailyThreshold))")
                                .fontWeight(.medium)
                        } else {
                            SettingsControls.numberField($customDailyThreshold)
                        }
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Card {
                SettingsRow(
                    L10n.generalDailyThresholdSmartMode,
                    subtitle: L10n.generalDailyThresholdSmartModeHint
                ) {
                    SettingsControls.switchToggle($dailyThresholdSmartMode)
                }
                RowDivider()
                SettingsRow(
                    L10n.generalDailyThresholdWorkingDays,
                    subtitle: L10n.generalDailyThresholdWorkingDaysHint,
                    isEnabled: dailyThresholdSmartMode
                ) {
                    SettingsControls.switchToggle($dailyThresholdWorkingDaysOnly)
                        .settingsControlEnabled(dailyThresholdSmartMode)
                }
            }
        }
    }

    private var thresholdPreview: String? {
        guard let snap = model.snapshot else { return nil }
        let workingDaysOnly = dailyThresholdSmartMode && dailyThresholdWorkingDaysOnly
        let days = UsageSnapshot.daysUntil(
            cycleEnd: snap.cycleEndDate,
            from: snap.fetchedAt,
            workingDaysOnly: workingDaysOnly
        )
        return L10n.generalDailyThresholdSmartPreview(
            AlertEngine.fmt(snap.remainingPercent),
            days,
            workingDaysOnly
        )
    }
}
