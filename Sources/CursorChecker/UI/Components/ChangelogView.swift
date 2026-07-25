import SwiftUI

struct ChangelogContentView: View {
    let entries: [ChangelogEntry]

    var body: some View {
        if entries.isEmpty {
            Text(Changelog.isAvailable ? L10n.changelogEmpty : L10n.changelogUnavailable)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(entries) { entry in
                    ChangelogEntryView(entry: entry)
                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ChangelogEntryView: View {
    let entry: ChangelogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.changelogVersion(entry.version))
                    .font(.title3.weight(.semibold))
                Spacer(minLength: 12)
                Text(Changelog.formattedDate(entry.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(entry.sections) { section in
                ChangelogSectionView(section: section)
            }
        }
    }
}

private struct ChangelogSectionView: View {
    let section: ChangelogSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(section.items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                        Text(item)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct ChangelogPanel: View {
    let title: String
    let entries: [ChangelogEntry]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(L10n.commonClose, action: onClose)
            }
            .padding()

            Divider()

            ScrollView {
                ChangelogContentView(entries: entries)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Backward-compatible name for older call sites.
typealias ChangelogSheet = ChangelogPanel
