import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case basics, connection, overview, general, menuBar, notifications, journal, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:      return L10n.settingsTabOverview
        case .connection:    return L10n.settingsTabConnection
        case .basics:        return L10n.settingsTabBasics
        case .general:       return L10n.settingsTabGeneral
        case .menuBar:       return L10n.settingsTabMenuBar
        case .notifications: return L10n.settingsTabNotifications
        case .journal:       return L10n.settingsTabJournal
        case .about:         return L10n.settingsTabAbout
        }
    }

    var symbol: String {
        switch self {
        case .overview:      return "chart.bar.fill"
        case .connection:    return "key.fill"
        case .basics:        return "gearshape.fill"
        case .general:       return "gauge.with.dots.needle.67percent"
        case .menuBar:       return "menubar.rectangle"
        case .notifications: return "bell.badge.fill"
        case .journal:       return "list.bullet.rectangle.fill"
        case .about:         return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .overview:      return .green
        case .connection:    return .purple
        case .basics:        return .indigo
        case .general:       return .blue
        case .menuBar:       return .orange
        case .notifications: return .red
        case .journal:       return .teal
        case .about:         return .gray
        }
    }
}
