import SwiftUI

/// Section title above a settings card group.
struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
    }
}

/// A rounded grouped container, matching the System Settings card look.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A single row inside a `Card`: title (+ optional subtitle) on the left, a
/// trailing control on the right.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var isEnabled: Bool = true
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        isEnabled: Bool = true,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isEnabled ? .secondary : .tertiary)
                }
            }
            Spacer(minLength: 12)
            trailing
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

/// An inset divider between rows, like the separators in System Settings.
struct RowDivider: View {
    var body: some View {
        Divider().padding(.leading, 14)
    }
}
