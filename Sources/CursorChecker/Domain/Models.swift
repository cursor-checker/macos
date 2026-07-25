import Foundation

/// Response shape of the (unofficial) Cursor dashboard endpoint
/// POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage
struct PeriodUsageResponse: Codable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let planUsage: PlanUsage?
}

struct PlanUsage: Codable {
    let totalSpend: Double?
    let includedSpend: Double?
    let bonusSpend: Double?
    let limit: Double?
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
}

/// Normalized snapshot the rest of the app works with.
struct UsageSnapshot {
    let fetchedAt: Date
    let cycleStartMs: Double
    let cycleEndMs: Double
    let totalPercentUsed: Double
    let autoPercentUsed: Double
    let apiPercentUsed: Double
    let totalSpendUSD: Double

    var remainingPercent: Double { max(0, 100 - totalPercentUsed) }

    var cycleStartDate: Date { Date(timeIntervalSince1970: cycleStartMs / 1000.0) }
    var cycleEndDate: Date { Date(timeIntervalSince1970: cycleEndMs / 1000.0) }

    /// One-line menu text: «Оплачен до: 20.07 14:00 (1 день)».
    func cycleResetMenuLine(at now: Date = Date()) -> String {
        let days = Self.daysUntil(cycleEnd: cycleEndDate, from: now)
        return L10n.cycleResetLine(Self.shortResetDate(cycleEndDate), Self.daysLabel(days))
    }

    static func daysUntil(cycleEnd: Date, from now: Date, workingDaysOnly: Bool = false) -> Int {
        let cal = Calendar.current
        let fromDay = cal.startOfDay(for: now)
        let toDay = cal.startOfDay(for: cycleEnd)
        guard fromDay < toDay else { return 0 }

        if !workingDaysOnly {
            return cal.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
        }

        var count = 0
        var current = fromDay
        while current < toDay {
            let weekday = cal.component(.weekday, from: current)
            if weekday != 1, weekday != 7 {
                count += 1
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return count
    }

    static func daysLabel(_ days: Int) -> String {
        L10n.daysLabel(days)
    }

    static func shortResetDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM HH:mm"
        return f.string(from: date)
    }
}

enum UsageError: Error, CustomStringConvertible {
    case noToken
    case tokenExpired
    case http(Int, String)
    case decode(String)
    case network(String)

    var description: String {
        switch self {
        case .noToken:
            return L10n.errorNoToken
        case .tokenExpired:
            return L10n.errorTokenExpired
        case .http(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .decode(let msg):
            return L10n.errorDecode(msg)
        case .network(let msg):
            return L10n.errorNetwork(msg)
        }
    }

    /// English text for the activity journal (always logged in English).
    var journalDescription: String {
        switch self {
        case .noToken:
            return "Cursor token not found. Sign in to the Cursor app."
        case .tokenExpired:
            return "Cursor token expired. Open Cursor to refresh the session."
        case .http(let code, let body):
            return "HTTP \(code): \(body.prefix(200))"
        case .decode(let msg):
            return "Couldn't parse response: \(msg)"
        case .network(let msg):
            return "Network: \(msg)"
        }
    }
}
