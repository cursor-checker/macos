import Foundation

struct ChangelogEntry: Identifiable, Equatable {
    var id: String { version }
    let version: String
    let date: String
    let sections: [ChangelogSection]
}

struct ChangelogSection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let items: [String]
}

/// Reads and parses bundled Keep a Changelog files shipped with the app.
/// Content is localized: Russian (`CHANGELOG.md`) and English (`CHANGELOG.en.md`).
enum Changelog {
    static var entries: [ChangelogEntry] {
        parseEntries(from: fullText)
    }

    static var fullText: String {
        let embedded = L10n.resolvedLanguageCode == "en" ? ChangelogData.textEn : ChangelogData.textRu
        if !embedded.isEmpty {
            return embedded
        }
        guard let url = bundledURL,
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.isEmpty else {
            return ""
        }
        return text
    }

    static var isAvailable: Bool {
        !fullText.isEmpty
    }

    static func section(for version: String) -> String? {
        let normalized = normalizeVersion(version)
        let escaped = NSRegularExpression.escapedPattern(for: normalized)
        let pattern = "## \\[\(escaped)\\] - \\d{4}-\\d{2}-\\d{2}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let text = fullText as NSString
        let range = NSRange(location: 0, length: text.length)
        guard let match = regex.firstMatch(in: fullText, range: range) else { return nil }

        let start = match.range.location
        let tail = text.substring(from: start)
        if let nextHeading = tail.range(of: "\n## [") {
            return String(tail[..<nextHeading.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return tail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseEntries(from text: String) -> [ChangelogEntry] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var entries: [ChangelogEntry] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if let entry = parseEntryHeader(line) {
                index += 1
                let (sections, nextIndex) = parseSections(in: lines, startingAt: index)
                index = nextIndex
                if !sections.isEmpty {
                    entries.append(
                        ChangelogEntry(version: entry.version, date: entry.date, sections: sections)
                    )
                }
            } else {
                index += 1
            }
        }

        return entries
    }

    static func formattedDate(_ isoDate: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDate) else { return isoDate }

        let display = DateFormatter()
        display.locale = Locale(identifier: L10n.resolvedLanguageCode == "en" ? "en_US" : "ru_RU")
        display.dateStyle = .long
        display.timeStyle = .none
        return display.string(from: date)
    }

    private static func parseEntryHeader(_ line: String) -> (version: String, date: String)? {
        let pattern = #"^## \[(.+?)\] - (\d{4}-\d{2}-\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 3,
              let versionRange = Range(match.range(at: 1), in: line),
              let dateRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[versionRange]), String(line[dateRange]))
    }

    private static func parseSections(
        in lines: [String],
        startingAt start: Int
    ) -> ([ChangelogSection], Int) {
        var sections: [ChangelogSection] = []
        var currentTitle: String?
        var currentItems: [String] = []
        var index = start

        func flushSection() {
            guard let currentTitle, !currentItems.isEmpty else { return }
            sections.append(ChangelogSection(title: currentTitle, items: currentItems))
            currentItems = []
        }

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## [") { break }

            if trimmed.hasPrefix("### ") {
                flushSection()
                currentTitle = String(trimmed.dropFirst(4))
            } else if trimmed.hasPrefix("- ") {
                currentItems.append(String(trimmed.dropFirst(2)))
            }

            index += 1
        }

        flushSection()
        return (sections, index)
    }

    private static var bundledURL: URL? {
        let resource = L10n.resolvedLanguageCode == "en" ? "CHANGELOG.en" : "CHANGELOG"
        return AppResources.url(forResource: resource, withExtension: "md")
            ?? AppResources.url(forResource: "CHANGELOG", withExtension: "md")
    }

    private static func normalizeVersion(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}
