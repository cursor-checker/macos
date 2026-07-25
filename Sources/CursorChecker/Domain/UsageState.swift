import Foundation

/// Persisted tracking state used to compute "spent today" and to avoid
/// re-sending the same alert.
struct UsageState: Codable, Equatable {
    /// Billing cycle this state belongs to (ms). Reset everything when it changes.
    var cycleStartMs: Double = 0

    /// Local calendar day key (yyyy-MM-dd) the baseline was captured for.
    var dayKey: String = ""

    /// Cycle usage percent captured at the first poll of `dayKey`.
    var dayBaselinePercent: Double = 0

    /// Highest daily-threshold step already notified today (0 = none).
    /// step N means we've alerted that today's growth reached N * dailyThresholdPercent.
    var lastDailyStepNotified: Int = 0

    static var fileURL: URL { Config.directory.appendingPathComponent("state.json") }

    static func load() -> UsageState {
        Config.ensureDirectory()
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(UsageState.self, from: data) else {
            return UsageState()
        }
        return s
    }

    func save() {
        Config.ensureDirectory()
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) {
            try? data.write(to: UsageState.fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: UsageState.fileURL.path)
        }
    }

    static func dayKey(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar.current
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

/// An alert the app decided to raise after processing a snapshot.
struct Alert {
    let title: String
    let body: String
}

/// Pure logic: given a snapshot + config, update state and return any alerts to send.
enum AlertEngine {
    static func process(snapshot: UsageSnapshot,
                        config: Config,
                        state: inout UsageState) -> [Alert] {
        var alerts: [Alert] = []
        let original = state
        let today = UsageState.dayKey(for: snapshot.fetchedAt)

        // New billing cycle -> reset tracking.
        if state.cycleStartMs != snapshot.cycleStartMs {
            state.cycleStartMs = snapshot.cycleStartMs
            state.dayKey = today
            state.dayBaselinePercent = snapshot.totalPercentUsed
            state.lastDailyStepNotified = 0
        }

        // New day -> reset the daily baseline.
        if state.dayKey != today {
            state.dayKey = today
            state.dayBaselinePercent = snapshot.totalPercentUsed
            state.lastDailyStepNotified = 0
        }

        // Guard against a baseline higher than current (e.g. manual state edits).
        if snapshot.totalPercentUsed < state.dayBaselinePercent {
            state.dayBaselinePercent = snapshot.totalPercentUsed
        }

        let spentToday = max(0, snapshot.totalPercentUsed - state.dayBaselinePercent)

        // --- Daily threshold (stepped) ---
        let step = Self.effectiveDailyThreshold(config: config, snapshot: snapshot)
        if step > 0 {
            let currentStep = Int(floor(spentToday / step))
            if currentStep > state.lastDailyStepNotified {
                let reached = Double(currentStep) * step
                alerts.append(Alert(
                    title: L10n.alertDailyTitle(fmt(spentToday)),
                    body: L10n.alertDailyBody(fmt(reached), fmt(step), fmt(snapshot.totalPercentUsed))
                ))
                state.lastDailyStepNotified = currentStep
            }
        }

        if state != original {
            state.save()
        }
        return alerts
    }

    static func spentToday(snapshot: UsageSnapshot, state: UsageState) -> Double {
        let today = UsageState.dayKey(for: snapshot.fetchedAt)
        guard state.dayKey == today, state.cycleStartMs == snapshot.cycleStartMs else {
            return 0
        }
        return max(0, snapshot.totalPercentUsed - state.dayBaselinePercent)
    }

    /// Share of today's daily quota used: spentToday / dailyQuotaPercent × 100.
    /// e.g. 2% spent of a 5% daily quota → 40%.
    static func dailyQuotaUsedPercent(spentToday: Double, dailyQuotaPercent: Double) -> Double {
        guard dailyQuotaPercent > 0 else { return 0 }
        return spentToday / dailyQuotaPercent * 100
    }

    /// Share of today's daily quota still available.
    /// e.g. 3% spent of a 5% daily quota → 40% remaining.
    static func dailyQuotaRemainingPercent(spentToday: Double, dailyQuotaPercent: Double) -> Double {
        max(0, 100 - dailyQuotaUsedPercent(spentToday: spentToday, dailyQuotaPercent: dailyQuotaPercent))
    }

    static func fmt(_ v: Double) -> String {
        String(format: "%.1f", v)
    }

    /// Fixed manual threshold, or remaining quota ÷ remaining days in smart mode.
    static func effectiveDailyThreshold(config: Config,
                                        snapshot: UsageSnapshot?,
                                        now: Date = Date()) -> Double {
        guard config.resolvedDailyThresholdSmartMode, let snapshot else {
            return config.dailyThresholdPercent
        }

        let days = UsageSnapshot.daysUntil(
            cycleEnd: snapshot.cycleEndDate,
            from: now,
            workingDaysOnly: config.resolvedDailyThresholdWorkingDaysOnly
        )
        let divisor = max(1, days)
        return snapshot.remainingPercent / Double(divisor)
    }
}
