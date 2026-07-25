import SwiftUI

struct AboutSettingsSection: View {
    @ObservedObject var model: AppModel
    @Binding var updateChannel: UpdateChannel

    @State private var updateStatus: AppUpdateStatus = .idle
    @State private var updateAnimationStartedAt: Date?

    private let updateAnimationMinimumDuration: TimeInterval = 1

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                AppLogoView(size: 72)
                Text(AppInfo.displayName)
                    .font(.system(size: 22, weight: .semibold))
                Text(L10n.aboutTagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(L10n.aboutVersion(AppInfo.versionLabel))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 8) {
                Card {
                    SettingsRow(L10n.aboutUpdateChannel) {
                        Picker("", selection: $updateChannel) {
                            ForEach(UpdateChannel.allCases) { channel in
                                Text(channel.title).tag(channel)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 170, alignment: .trailing)
                    }
                    RowDivider()
                    SettingsRow(L10n.aboutUpdateCheck, subtitle: updateStatusSubtitle) {
                        updateActionControl
                    }
                    updateNotesRow
                    RowDivider()
                    SettingsRow(L10n.aboutChangelog) {
                        Button(L10n.commonShow) {
                            model.presentBundledChangelog()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Card {
                SettingsRow(L10n.aboutDeleteApp) {
                    Button(L10n.commonDelete) {
                        AppUninstaller.confirmAndUninstall()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)
            aboutFooter
        }
        .onAppear {
            checkForUpdates()
        }
        .onChange(of: updateChannel) { _, _ in
            updateStatus = .idle
            checkForUpdates()
        }
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Button { model.showLicenseSheet = true } label: {
                Text(licenseLinkLabel)
            }
            .buttonStyle(.plain)

            Text(AppInfo.copyrightNotice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }

    private var licenseLinkLabel: AttributedString {
        var label = AttributedString(L10n.licenseTitle)
        label.font = .caption
        label.foregroundColor = .secondary
        label.underlineStyle = .single
        return label
    }

    private var updateActionAvailable: Bool {
        switch updateStatus {
        case .checking, .downloading, .installing: return false
        default: return true
        }
    }

    private var updateStatusSubtitle: String? {
        switch updateStatus {
        case .idle:
            return nil
        case .checking:
            return L10n.aboutCheckingGitHub
        case .upToDate:
            return updateChannel == .beta
                ? L10n.aboutUpToDateBeta(AppInfo.versionLabel)
                : L10n.aboutUpToDateStable(AppInfo.versionLabel)
        case .updateAvailable(let version, _, _, _, let channel, _):
            return channel == .beta
                ? L10n.aboutUpdateAvailableBeta(version)
                : L10n.aboutUpdateAvailableStable(version)
        case .noReleases:
            return updateChannel == .beta
                ? L10n.aboutNoBetaReleases
                : L10n.aboutNoStableReleases
        case .downloading:
            return L10n.aboutDownloading
        case .installing:
            return L10n.aboutInstalling
        case .failed(let message):
            return message
        }
    }

    @ViewBuilder
    private var updateNotesRow: some View {
        if case .updateAvailable(let version, _, _, _, _, let releaseNotes) = updateStatus,
           let releaseNotes,
           !releaseNotes.isEmpty {
            RowDivider()
            SettingsRow(L10n.aboutWhatsNewIn(version), subtitle: L10n.aboutUpdateNotesSubtitle) {
                Button(L10n.commonShow) {
                    model.presentUpdateNotes(version: version, text: releaseNotes)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var updateActionControl: some View {
        switch updateStatus {
        case .checking, .downloading, .installing:
            ProgressView().controlSize(.small)
        case .updateAvailable(_, let releaseURL, let downloadURL, let checksumURL, _, _):
            HStack(spacing: 8) {
                Button(L10n.commonCheck) { checkForUpdates() }
                    .buttonStyle(.bordered)
                    .settingsButtonEnabled(updateActionAvailable)
                Button(downloadURL == nil ? L10n.commonDetails : L10n.commonUpdate) {
                    AppUpdater.shared.performUpdate(
                        releaseURL: releaseURL,
                        downloadURL: downloadURL,
                        checksumURL: checksumURL
                    ) { status in
                        applyUpdateStatus(status)
                    }
                }
                .buttonStyle(.bordered)
                .settingsButtonEnabled(updateActionAvailable)
            }
        default:
            Button(L10n.commonCheck) { checkForUpdates() }
                .settingsButtonEnabled(updateActionAvailable)
        }
    }

    private func checkForUpdates() {
        switch updateStatus {
        case .checking, .downloading, .installing:
            return
        default:
            break
        }
        ActivityJournal.shared.logAction(
            JournalLog.checkUpdates,
            detail: model.config.resolvedUpdateChannel == .beta ? "Beta" : "Stable"
        )
        beginUpdateAnimation(.checking)
        AppUpdater.shared.checkForUpdates(channel: model.config.resolvedUpdateChannel) {
            applyUpdateStatus($0)
        }
    }

    private func beginUpdateAnimation(_ status: AppUpdateStatus) {
        updateAnimationStartedAt = Date()
        updateStatus = status
    }

    private func applyUpdateStatus(_ status: AppUpdateStatus) {
        finishUpdateAnimation(with: status)
    }

    private func finishUpdateAnimation(with status: AppUpdateStatus) {
        guard let started = updateAnimationStartedAt else {
            updateStatus = status
            return
        }

        let delay = max(0, updateAnimationMinimumDuration - Date().timeIntervalSince(started))
        updateAnimationStartedAt = nil

        let apply = {
            switch status {
            case .checking, .downloading, .installing:
                self.beginUpdateAnimation(status)
            default:
                self.updateStatus = status
            }
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: apply)
        } else {
            apply()
        }
    }
}
