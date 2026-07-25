import Combine
import Foundation

enum JournalKind: String, Codable {
    case request
    case action
}

enum JournalStatus: Equatable, Codable {
    case success
    case failure(String)
}

struct JournalEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let date: Date
    let kind: JournalKind
    let title: String
    let detail: String?
    let status: JournalStatus
    let durationMs: Int?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: JournalKind,
        title: String,
        detail: String? = nil,
        status: JournalStatus,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.detail = detail
        self.status = status
        self.durationMs = durationMs
    }

    var logLine: String {
        let time = Self.timeFormatter.string(from: date)
        let tag = kind == .request ? "req" : "act"
        let outcome: String
        switch status {
        case .success: outcome = "ok"
        case .failure(let message): outcome = "err \(message)"
        }

        var parts = ["\(time)", tag]
        if kind == .request {
            if let detail, !detail.isEmpty { parts.append(detail) }
            parts.append(title)
        } else {
            parts.append(title)
            if let detail, !detail.isEmpty { parts.append(detail) }
        }
        parts.append(outcome)
        return parts.joined(separator: " ")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

/// In-app activity log:
/// Tokens, emails, chat IDs and response bodies are never stored.
/// Action titles/details are always written in English (`JournalLog`).
final class ActivityJournal: ObservableObject {

    static let shared = ActivityJournal()
    static let maxEntries = 500
    /// Legacy Application Support folder name (pre-1.2.6); removed on uninstall.
    static let legacyDirectoryNameForCleanup = legacyDirectoryName

    @Published private(set) var entries: [JournalEntry] = []
    @Published private(set) var isLoggingEnabled = false

    private let lock = NSLock()
    private var loggingEnabled = false

    var logText: String {
        if !isLoggingEnabled && entries.isEmpty { return L10n.journalLoggingDisabled }
        guard !entries.isEmpty else { return L10n.journalEmptyPlaceholder }
        return entries.reversed().map(\.logLine).joined(separator: "\n")
    }

    private static let legacyDirectoryName = "CursorChecker"

    private let persistURL: URL

    private init() {
        Config.ensureDirectory()
        persistURL = Config.directory.appendingPathComponent("journal.json")
        Self.migrateLegacyJournalIfNeeded(to: persistURL)
        entries = Self.load(from: persistURL)
        loggingEnabled = Config.loadJournalLoggingEnabled()
        isLoggingEnabled = loggingEnabled
    }

    // MARK: - Public API

    func setLoggingEnabled(_ enabled: Bool) {
        lock.lock()
        loggingEnabled = enabled
        lock.unlock()
        mutate { self.isLoggingEnabled = enabled }
    }

    func logRequest(
        endpoint: String,
        method: String = "GET",
        statusCode: Int? = nil,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        guard isLoggingEnabledNow else { return }
        let title = Self.sanitizeEndpoint(endpoint)
        let detail = Self.requestDetail(method: method, statusCode: statusCode, duration: duration)
        let status = Self.requestStatus(statusCode: statusCode, error: error)
        append(JournalEntry(
            kind: .request,
            title: title,
            detail: detail,
            status: status,
            durationMs: duration.map { Int($0 * 1000) }
        ))
    }

    func logAction(
        _ title: String,
        detail: String? = nil,
        success: Bool = true,
        error: String? = nil
    ) {
        guard isLoggingEnabledNow else { return }
        let status: JournalStatus
        if let error {
            status = .failure(Self.sanitizeText(error))
        } else if success {
            status = .success
        } else {
            status = .failure(JournalLog.actionFailed)
        }
        append(JournalEntry(
            kind: .action,
            title: Self.sanitizeText(title),
            detail: detail.map { Self.sanitizeText($0) },
            status: status
        ))
    }

    func clear() {
        mutate {
            self.entries = []
            try? FileManager.default.removeItem(at: self.persistURL)
        }
    }

    // MARK: - Sanitization

    static func sanitizeEndpoint(_ raw: String) -> String {
        if let url = URL(string: raw), let host = url.host {
            var path = url.path
            if path.range(of: #"/bot[^/]+"#, options: .regularExpression) != nil {
                path = path.replacingOccurrences(
                    of: #"/bot[^/]+"#,
                    with: "/bot***",
                    options: .regularExpression
                )
            }
            return host + path
        }
        return sanitizeText(raw)
    }

    static func sanitizeText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"Bearer\s+\S+"#,
            with: "Bearer ***",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\bbot\d+:[A-Za-z0-9_-]+"#,
            with: "bot***",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            with: "***@***",
            options: .regularExpression
        )
        if result.count > 160 {
            result = String(result.prefix(160)) + "…"
        }
        return result
    }

    // MARK: - Private

    private var isLoggingEnabledNow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return loggingEnabled
    }

    private static func requestDetail(
        method: String,
        statusCode: Int?,
        duration: TimeInterval?
    ) -> String {
        var parts = [method.uppercased()]
        if let statusCode { parts.append("\(statusCode)") }
        if let duration { parts.append("\(Int(duration * 1000))ms") }
        return parts.joined(separator: " ")
    }

    private static func requestStatus(statusCode: Int?, error: String?) -> JournalStatus {
        if let error { return .failure(sanitizeText(error)) }
        if let statusCode, !(200..<300).contains(statusCode) {
            return .failure("\(statusCode)")
        }
        return .success
    }

    private func append(_ entry: JournalEntry) {
        mutate {
            self.entries.insert(entry, at: 0)
            if self.entries.count > Self.maxEntries {
                self.entries.removeLast(self.entries.count - Self.maxEntries)
            }
            self.persist()
        }
    }

    private func mutate(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: persistURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: persistURL.path)
    }

    private static func migrateLegacyJournalIfNeeded(to destination: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else { return }
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let legacyURL = support
            .appendingPathComponent(legacyDirectoryName, isDirectory: true)
            .appendingPathComponent("journal.json")
        guard fm.fileExists(atPath: legacyURL.path) else { return }
        try? fm.moveItem(at: legacyURL, to: destination)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        let legacyDir = legacyURL.deletingLastPathComponent()
        if let contents = try? fm.contentsOfDirectory(atPath: legacyDir.path), contents.isEmpty {
            try? fm.removeItem(at: legacyDir)
        }
    }

    private static func load(from url: URL) -> [JournalEntry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else {
            return []
        }
        return Array(decoded.prefix(maxEntries))
    }
}
