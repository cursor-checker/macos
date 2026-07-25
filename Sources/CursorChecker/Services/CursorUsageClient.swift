import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Reads the local Cursor session token and queries the current billing-period usage.
///
/// The token lives in Cursor's `state.vscdb` (the same SQLite file the editor uses).
/// We only ever read it and send it to Cursor's own server (`api2.cursor.sh`) — the
/// exact host the editor talks to. Nothing is sent to any third party.
struct CursorUsageClient {

    struct StoredCursorCredentials: Codable, Equatable {
        var token: String
        var email: String?
    }

    static let dbPath = NSString(string:
        "~/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    ).expandingTildeInPath

    private static let endpoint =
        "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"

    // MARK: - Token

    static func readItem(_ key: String) -> String? {
        var db: OpaquePointer?
        // Prefer a normal read-only open (works while Cursor holds the WAL).
        // Fall back to immutable if the file can't be opened for reads.
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        let uris = [
            "file:\(dbPath)?mode=ro",
            "file:\(dbPath)?immutable=1"
        ]
        for uri in uris {
            if sqlite3_open_v2(uri, &db, openFlags, nil) == SQLITE_OK {
                defer { sqlite3_close(db) }
                var stmt: OpaquePointer?
                let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1"
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
                if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
                    return String(cString: c)
                }
                return nil
            }
            if db != nil { sqlite3_close(db); db = nil }
        }
        return nil
    }

    static func readTokenFromCursor() -> String? {
        readItem("cursorAuth/accessToken")
    }

    static func cachedEmailFromCursor() -> String? {
        readItem("cursorAuth/cachedEmail")
    }

    /// Stored secrets first, then Cursor DB — used by CLI and opportunistic reads.
    static func readToken() -> String? {
        if let stored = storedToken(), !stored.isEmpty { return stored }
        return readTokenFromCursor()
    }

    static var hasStoredCredentials: Bool {
        guard let token = storedToken() else { return false }
        return !token.isEmpty
    }

    static func storedToken() -> String? {
        if let raw = SecretStore.get(Config.cursorCredentialsAccount), !raw.isEmpty {
            if raw.first == "{" {
                if let data = raw.data(using: .utf8),
                   let credentials = try? JSONDecoder().decode(StoredCursorCredentials.self, from: data),
                   !credentials.token.isEmpty {
                    return credentials.token
                }
                return nil
            }
            return raw
        }
        return SecretStore.get(Config.legacyCursorTokenAccount)
    }

    static func saveToken(_ token: String) {
        SecretStore.set(token, account: Config.cursorCredentialsAccount)
        SecretStore.delete(Config.legacyCursorTokenAccount)
        SecretStore.delete(Config.legacyCursorEmailAccount)
    }

    static func clearStoredToken() {
        SecretStore.delete(Config.cursorCredentialsAccount)
        SecretStore.delete(Config.legacyCursorTokenAccount)
        SecretStore.delete(Config.legacyCursorEmailAccount)
    }

    /// Token for API calls while connected — only the saved secret token.
    private static func tokenForRequest() -> String? {
        storedToken()
    }

    /// Decodes the JWT expiry (`exp`) without verifying the signature.
    static func tokenExpiry(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    // MARK: - Fetch

    static func fetch(completion: @escaping (Result<UsageSnapshot, UsageError>) -> Void) {
        guard let token = tokenForRequest(), !token.isEmpty else {
            completion(.failure(.noToken)); return
        }
        if let exp = tokenExpiry(token), exp < Date() {
            completion(.failure(.tokenExpired)); return
        }

        guard let url = URL(string: endpoint) else {
            completion(.failure(.network("bad url"))); return
        }
        var req = URLRequest(url: url, timeoutInterval: 25)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        req.setValue("cursor-checker", forHTTPHeaderField: "User-Agent")
        req.httpBody = "{}".data(using: .utf8)

        let started = Date()
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let duration = Date().timeIntervalSince(started)
            func journalLog(statusCode: Int? = nil, error: String? = nil) {
                ActivityJournal.shared.logRequest(
                    endpoint: Self.endpoint,
                    method: "POST",
                    statusCode: statusCode,
                    duration: duration,
                    error: error
                )
            }

            if let err = err {
                journalLog(error: err.localizedDescription)
                completion(.failure(.network(err.localizedDescription))); return
            }
            guard let http = resp as? HTTPURLResponse else {
                journalLog(error: "no response")
                completion(.failure(.network("no response"))); return
            }
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            guard (200..<300).contains(http.statusCode) else {
                journalLog(statusCode: http.statusCode)
                if http.statusCode == 401 || http.statusCode == 403 {
                    completion(.failure(.tokenExpired))
                } else {
                    completion(.failure(.http(http.statusCode, body)))
                }
                return
            }
            guard let data = data else {
                journalLog(statusCode: http.statusCode, error: "empty body")
                completion(.failure(.decode("empty body"))); return
            }
            do {
                let decoded = try JSONDecoder().decode(PeriodUsageResponse.self, from: data)
                guard let plan = decoded.planUsage,
                      let pct = plan.totalPercentUsed else {
                    journalLog(statusCode: http.statusCode, error: "missing usage data")
                    completion(.failure(.decode("missing planUsage.totalPercentUsed")))
                    return
                }
                journalLog(statusCode: http.statusCode)
                let snap = UsageSnapshot(
                    fetchedAt: Date(),
                    cycleStartMs: Double(decoded.billingCycleStart ?? "0") ?? 0,
                    cycleEndMs: Double(decoded.billingCycleEnd ?? "0") ?? 0,
                    totalPercentUsed: pct,
                    autoPercentUsed: plan.autoPercentUsed ?? 0,
                    apiPercentUsed: plan.apiPercentUsed ?? 0,
                    totalSpendUSD: (plan.totalSpend ?? 0) / 100.0
                )
                completion(.success(snap))
            } catch {
                journalLog(statusCode: http.statusCode, error: "decode failed")
                completion(.failure(.decode("\(error)")))
            }
        }.resume()
    }
}
