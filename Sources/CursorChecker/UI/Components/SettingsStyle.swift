import AppKit
import SwiftUI

/// Colors aligned with macOS System Settings grouped panels.
enum SettingsColors {
    /// Sidebar pane — light gray in Aqua.
    static let sidebarBackground = Color(nsColor: .windowBackgroundColor)
    /// Detail pane — white document surface in Aqua.
    static let panelBackground = Color(nsColor: .textBackgroundColor)
    static let cardBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 0.22, alpha: 1)
            : NSColor(calibratedWhite: 0.965, alpha: 1)
    }))
}

enum SettingsLayout {
    static let sectionHeaderIndent: CGFloat = 12
    static let sidebarWidth: CGFloat = 205
    /// Unified title bar row height (traffic lights + toolbar).
    static let titleBarContentHeight: CGFloat = 52
    /// Toolbar row sitting in the unified title bar (below traffic lights).
    static let detailToolbarTopInset: CGFloat = 8
    static let detailToolbarHeight: CGFloat = 32
    static let windowWidth: CGFloat = 720
    static let windowMinHeight: CGFloat = 420
}

/// Makes disabled controls look inactive — macOS `.disabled()` alone is too subtle.
extension View {
    func settingsControlEnabled(_ isEnabled: Bool) -> some View {
        self
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
            .background {
                if !isEnabled {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlColor))
                }
            }
    }

    func settingsButtonEnabled(_ isEnabled: Bool) -> some View {
        self
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
    }
}
