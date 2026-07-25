import SwiftUI

/// The usage details window: the same numbers the menu used to show, laid out
/// with a progress bar and a refresh button.
struct DetailsView: View {
    @ObservedObject var model: AppModel
    /// When embedded in the settings sidebar, hide the window chrome and stretch to width.
    var embedded: Bool = false

    @State private var breakdownExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: embedded ? 22 : 14) {
            if !embedded {
                header
                Divider()
            }
            content
        }
        .padding(embedded ? 0 : 20)
        .frame(maxWidth: embedded ? .infinity : nil)
        .frame(width: embedded ? nil : 340)
    }

    private var header: some View {
        HStack {
            Text(AppInfo.displayName).font(.headline)
            Spacer()
        }
    }

    private var refreshPillButton: some View {
        Button(action: { model.refresh() }) {
            ZStack {
                Text(L10n.commonRefresh)
                    .hidden()
                    .overlay {
                        ZStack {
                            Text(L10n.commonRefresh)
                                .opacity(model.isRefreshing ? 0.35 : 1)
                            if model.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(model.isRefreshing || !model.isCursorConnected)
        .help(L10n.commonRefreshNow)
    }

    @ViewBuilder
    private var content: some View {
        if !model.isCursorConnected {
            disconnectedState
        } else if let snap = model.snapshot {
            usage(snap)
        } else if let err = model.lastError {
            Label(err, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.6)
                Text(L10n.commonLoading).foregroundColor(.secondary)
            }
        }
    }

    private var disconnectedState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.overviewDisconnectedTitle, systemImage: "link.badge.plus")
                .foregroundColor(.secondary)
            Text(L10n.overviewDisconnectedBody)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func usage(_ snap: UsageSnapshot) -> some View {
        VStack(spacing: 22) {
            overviewCard {
                totalSection(snap)
                breakdownSection(snap)
            }
            overviewCard {
                todaySection()
                overviewRowDivider
                remainingSection()
                overviewRowDivider
                footerSection(snap)
            }
            HStack {
                Spacer()
                refreshPillButton
            }
        }
    }

    private func totalSection(_ snap: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.commonTotalSpent)
                Spacer()
                Text("\(AlertEngine.fmt(snap.totalPercentUsed))%")
                    .fontWeight(.semibold)
            }
            ProgressView(value: min(snap.totalPercentUsed, 100), total: 100)
                .tint(.accentColor)
        }
        .padding(.vertical, 11)
    }

    private func todaySection() -> some View {
        let spent = model.spentToday
        let threshold = model.effectiveDailyThreshold
        let overThreshold = threshold > 0 && spent >= threshold
        let fill = threshold > 0
            ? min(AlertEngine.dailyQuotaUsedPercent(spentToday: spent, dailyQuotaPercent: threshold), 100)
            : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.commonToday)
                    Text(L10n.thresholdValue("\(AlertEngine.fmt(threshold))%"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
                Text("+\(AlertEngine.fmt(spent))%")
                    .fontWeight(.semibold)
                    .foregroundColor(overThreshold ? .orange : .primary)
            }
            if threshold > 0 {
                ProgressView(value: fill, total: 100)
                    .tint(overThreshold ? .orange : .accentColor)
            }
        }
        .padding(.vertical, 11)
    }

    private func remainingSection() -> some View {
        let spent = model.spentToday
        let threshold = model.effectiveDailyThreshold
        let remaining = AlertEngine.dailyQuotaRemainingPercent(
            spentToday: spent,
            dailyQuotaPercent: threshold
        )

        return HStack {
            Text(L10n.commonRemaining)
            Spacer()
            Text("\(AlertEngine.fmt(remaining))%")
                .fontWeight(.semibold)
        }
        .padding(.vertical, 11)
    }

    private func footerSection(_ snap: UsageSnapshot) -> some View {
        HStack {
            Text(L10n.commonUpdated)
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
            Text(updatedAtString(snap.fetchedAt))
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 11)
    }

    private func updatedAtString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private var overviewRowDivider: some View {
        Divider()
    }

    private func overviewCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OverviewColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func breakdownSection(_ snap: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { breakdownExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(breakdownSummary(snap))
                        .foregroundColor(.secondary)
                    Spacer(minLength: 8)
                    Image(systemName: breakdownExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if breakdownExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    categoryBreakdown(
                        title: L10n.overviewBreakdownAutoTitle,
                        percent: snap.autoPercentUsed,
                        caption: L10n.overviewBreakdownAutoCaption
                    )
                    categoryBreakdown(
                        title: L10n.overviewBreakdownAPITitle,
                        percent: snap.apiPercentUsed,
                        caption: L10n.overviewBreakdownAPICaption
                    )
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 10)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 11)
    }

    private func breakdownSummary(_ snap: UsageSnapshot) -> String {
        L10n.overviewBreakdownSummary(
            "\(AlertEngine.fmt(snap.autoPercentUsed))%",
            "\(AlertEngine.fmt(snap.apiPercentUsed))%"
        )
    }

    private func categoryBreakdown(title: String, percent: Double, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(AlertEngine.fmt(percent))%")
                    .fontWeight(.medium)
            }
            ProgressView(value: min(percent, 100), total: 100)
            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum OverviewColors {
    static let cardBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.22, alpha: 1)
            : NSColor(calibratedWhite: 0.965, alpha: 1)
    }))
}
