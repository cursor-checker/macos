import Foundation

enum AppUpdateVersion {
    static func zipAssetName(version: String) -> String {
        "CursorChecker-\(version).zip"
    }

    static func checksumAssetName(version: String) -> String {
        "\(zipAssetName(version: version)).sha256"
    }

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    static func comparableBase(_ raw: String) -> String {
        let normalized = normalized(raw)
        return String(normalized.split(separator: "-", maxSplits: 1).first ?? Substring(normalized))
    }

    static func isReleaseNewer(_ latest: String, than current: String) -> Bool {
        let latestBase = comparableBase(latest)
        let currentBase = comparableBase(current)
        switch compare(latestBase, currentBase) {
        case .orderedDescending:
            return true
        case .orderedAscending:
            return false
        case .orderedSame:
            return latest != current
        }
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    static func parseSHA256(from text: String) throws -> String {
        let token = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init) ?? ""
        let normalized = token.lowercased()
        guard normalized.count == 64,
              normalized.allSatisfy({ $0.isHexDigit }) else {
            throw AppUpdateError.checksumInvalid
        }
        return normalized
    }
}
