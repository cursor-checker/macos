import XCTest
@testable import CursorChecker

final class AlertEnginePacingTests: XCTestCase {
    private let cycleStartMs: Double = 1_700_000_000_000
    private let dayMs: Double = 86_400_000

    func testPacingUsesStartOfDayRemainingWhenStateMatches() {
        let now = date(2026, 7, 15, 18, 0)
        let snap = snapshot(totalUsed: 55, fetchedAt: now, daysUntilEnd: 10)
        var state = UsageState()
        state.cycleStartMs = cycleStartMs
        state.dayKey = UsageState.dayKey(for: now)
        state.dayBaselinePercent = 40

        let pacing = AlertEngine.pacingRemainingPercent(snapshot: snap, state: state, now: now)
        XCTAssertEqual(pacing, 60, accuracy: 0.001)
    }

    func testMidDaySpendDoesNotShrinkSmartThreshold() {
        let morning = date(2026, 7, 15, 9, 0)
        let evening = date(2026, 7, 15, 21, 0)
        let daysUntilEnd = 10

        var state = UsageState()
        state.cycleStartMs = cycleStartMs
        state.dayKey = UsageState.dayKey(for: morning)
        state.dayBaselinePercent = 40

        let morningSnap = snapshot(totalUsed: 40, fetchedAt: morning, daysUntilEnd: daysUntilEnd)
        let eveningSnap = snapshot(totalUsed: 55, fetchedAt: evening, daysUntilEnd: daysUntilEnd)

        let morningThreshold = AlertEngine.effectiveDailyThreshold(
            config: smartConfig(),
            snapshot: morningSnap,
            state: state,
            now: morning
        )
        let eveningThreshold = AlertEngine.effectiveDailyThreshold(
            config: smartConfig(),
            snapshot: eveningSnap,
            state: state,
            now: evening
        )

        XCTAssertEqual(morningThreshold, 6, accuracy: 0.001)
        XCTAssertEqual(eveningThreshold, morningThreshold, accuracy: 0.001)
    }

    func testDayOrCycleMismatchFallsBackToLiveRemaining() {
        let now = date(2026, 7, 15, 12, 0)
        let snap = snapshot(totalUsed: 55, fetchedAt: now, daysUntilEnd: 10)

        var staleDay = UsageState()
        staleDay.cycleStartMs = cycleStartMs
        staleDay.dayKey = "2026-07-14"
        staleDay.dayBaselinePercent = 40

        XCTAssertEqual(
            AlertEngine.pacingRemainingPercent(snapshot: snap, state: staleDay, now: now),
            snap.remainingPercent,
            accuracy: 0.001
        )

        var staleCycle = UsageState()
        staleCycle.cycleStartMs = cycleStartMs - dayMs
        staleCycle.dayKey = UsageState.dayKey(for: now)
        staleCycle.dayBaselinePercent = 40

        XCTAssertEqual(
            AlertEngine.pacingRemainingPercent(snapshot: snap, state: staleCycle, now: now),
            snap.remainingPercent,
            accuracy: 0.001
        )
    }

    func testAfterRolloverThresholdUsesNewMorningRemainingOverFewerDays() {
        let morning = date(2026, 7, 16, 9, 0)
        let snap = snapshot(totalUsed: 55, fetchedAt: morning, daysUntilEnd: 9)

        var state = UsageState()
        state.cycleStartMs = cycleStartMs
        state.dayKey = UsageState.dayKey(for: morning)
        state.dayBaselinePercent = 55

        let threshold = AlertEngine.effectiveDailyThreshold(
            config: smartConfig(),
            snapshot: snap,
            state: state,
            now: morning
        )

        // remaining at morning = 45%, days = 9 → 5%
        XCTAssertEqual(threshold, 5, accuracy: 0.001)
    }

    func testManualModeIgnoresSnapshotAndState() {
        var config = Config()
        config.dailyThresholdSmartMode = false
        config.dailyThresholdPercent = 7

        let threshold = AlertEngine.effectiveDailyThreshold(
            config: config,
            snapshot: nil,
            state: UsageState(),
            now: Date()
        )
        XCTAssertEqual(threshold, 7, accuracy: 0.001)
    }

    // MARK: - Helpers

    private func smartConfig() -> Config {
        var config = Config()
        config.dailyThresholdSmartMode = true
        config.dailyThresholdWorkingDaysOnly = false
        return config
    }

    private func snapshot(totalUsed: Double, fetchedAt: Date, daysUntilEnd: Int) -> UsageSnapshot {
        let end = Calendar.current.date(byAdding: .day, value: daysUntilEnd, to: Calendar.current.startOfDay(for: fetchedAt))!
        return UsageSnapshot(
            fetchedAt: fetchedAt,
            cycleStartMs: cycleStartMs,
            cycleEndMs: end.timeIntervalSince1970 * 1000,
            totalPercentUsed: totalUsed,
            autoPercentUsed: totalUsed,
            apiPercentUsed: 0,
            totalSpendUSD: 0
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return Calendar.current.date(from: comps)!
    }
}
