import SwiftUI

struct AppThemePicker: View {
    @Binding var selection: AppTheme

    private let previewSize = CGSize(width: 84, height: 52)
    private let themes: [AppTheme] = [.light, .dark, .system]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(themes) { theme in
                themeOption(theme)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func themeOption(_ theme: AppTheme) -> some View {
        let isSelected = selection == theme

        return Button {
            selection = theme
        } label: {
            VStack(spacing: 6) {
                ThemePreviewThumbnail(theme: theme)
                    .frame(width: previewSize.width, height: previewSize.height)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .inset(by: 1.5)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    }

                Text(theme.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: previewSize.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ThemePreviewThumbnail: View {
    let theme: AppTheme

    var body: some View {
        Group {
            switch theme {
            case .light:
                themeScene(isDark: false)
            case .dark:
                themeScene(isDark: true)
            case .system:
                HStack(spacing: 0) {
                    themeScene(isDark: false, compact: true)
                    themeScene(isDark: true, compact: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        }
    }

    private func themeScene(isDark: Bool, compact: Bool = false) -> some View {
        ZStack(alignment: .topLeading) {
            wallpaper(isDark: isDark)

            MiniWindowMockup(isDark: isDark)
                .frame(width: compact ? 26 : 48, height: compact ? 18 : 34)
                .padding(.top, compact ? 8 : 11)
                .padding(.leading, compact ? 6 : 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func wallpaper(isDark: Bool) -> some View {
        if isDark {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.03, green: 0.04, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.58, green: 0.76, blue: 0.98),
                    Color(red: 0.82, green: 0.90, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct MiniWindowMockup: View {
    let isDark: Bool

    private var windowBackground: Color {
        isDark ? Color(white: 0.18) : .white
    }

    private var sidebarColor: Color {
        isDark ? Color(white: 0.24) : Color(white: 0.93)
    }

    private var contentColor: Color {
        isDark ? Color(white: 0.16) : Color(white: 0.97)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(windowBackground)
                .shadow(color: .black.opacity(isDark ? 0.35 : 0.18), radius: 1.5, y: 1)

            HStack(spacing: 2) {
                trafficLight(.red)
                trafficLight(.yellow)
                trafficLight(.green)
            }
            .padding(3)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(sidebarColor)
                    .frame(width: 10)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(contentColor)
                    .padding(.vertical, 2)
                    .padding(.trailing, 2)
            }
            .padding(.top, 9)
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
    }

    private func trafficLight(_ color: TrafficLightColor) -> some View {
        Circle()
            .fill(color.fill)
            .frame(width: 3.5, height: 3.5)
    }

    private enum TrafficLightColor {
        case red, yellow, green

        var fill: Color {
            switch self {
            case .red:    return Color(red: 0.98, green: 0.37, blue: 0.33)
            case .yellow: return Color(red: 0.98, green: 0.76, blue: 0.18)
            case .green:  return Color(red: 0.36, green: 0.82, blue: 0.39)
            }
        }
    }
}
