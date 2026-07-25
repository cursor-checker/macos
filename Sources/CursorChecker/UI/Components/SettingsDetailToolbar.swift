import SwiftUI

/// Detail-column toolbar for the settings window.
///
/// NavigationView / NavigationStack on Xcode 27 beta are unreliable here (missing
/// title on first launch, wrong pane materials). This matches the native
/// System Settings row: ‹ › pill on the left and a section title beside it.
struct SettingsDetailToolbar: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            navigationPill

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, SettingsLayout.detailToolbarTopInset)
        .frame(maxWidth: .infinity, minHeight: SettingsLayout.detailToolbarHeight, alignment: .leading)
    }

    private var navigationPill: some View {
        HStack(spacing: 0) {
            navButton(systemName: "chevron.left", enabled: canGoBack, action: onBack)
                .accessibilityLabel(L10n.settingsNavBack)

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 1)

            navButton(systemName: "chevron.right", enabled: canGoForward, action: onForward)
                .accessibilityLabel(L10n.settingsNavForward)
        }
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 0.5, y: 0.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
        }
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}
