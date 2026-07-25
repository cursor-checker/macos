# Changelog

All notable changes to Cursor Checker are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.4.2] - 2026-07-21

### Added
- Smart daily threshold mode: threshold is automatically recalculated as remaining quota ÷ remaining days in the cycle
- "Workdays only" option for smart threshold calculation, excluding Saturday and Sunday
- Smart threshold calculation preview in settings (remaining quota and number of days)

### Fixed
- "Back" and "Forward" navigation in settings: works correctly for tabs, changelog, and license; history resets when the window is closed
- macOS system notifications on launch when not running from an .app bundle

### Improved
- Menu bar, warnings, notifications, and overview screen use the current threshold in smart mode

## [1.4.1-beta.1] - 2026-07-21

### Changed
- Beta release.

## [1.4.1] - 2026-07-21

### Fixed
- Dock window behavior
- Settings screen layout

### Changed
- Height of elements on the settings screen

## [1.4.0] - 2026-07-19

### Added
- Interface localization in Russian and English with language selection: system, Russian, or English
- "General" tab in settings — language, appearance theme, and launch at login
- Visual theme selection: light, dark, or system
- English version of the changelog in the app
- Drag-and-drop reordering of rows in menu bar row settings

### Fixed
- Incomplete localization in the changelog panel, license agreement, and parts of settings sections

### Changed
- Polling interval and daily threshold are set via numeric fields instead of preset values from a list
- "Launch at login" moved from "About" section to "General"
- Settings open on the "General" tab by default
- "Updated" row in the menu bar is shown separately from usage data
- Cycle end date in the menu is displayed as "Paid until" with the number of remaining days

### Improved
- App menu and settings window title update when the language changes without restart
- Appearance theme is applied immediately after selection
- Dates in the changelog are displayed in the format of the selected language

## [1.3.9] - 2026-07-18

### Fixed
- Fixed app icon rendering in the Dock and in-app UI — removed blur and incorrect masking

## [1.3.8] - 2026-07-18

### Added
- Full app icon set for all macOS sizes

### Fixed
- Correct icon display in notifications, Finder, and System Settings

### Improved
- Icon loading with fallback sources for reliable display in system UI
- Icon re-registration in the system when the app launches

## [1.3.7] - 2026-07-17

### Added
- Automatic permission request when enabling system notifications in settings
- Hint to open System Settings when macOS does not show the permission dialog
- Hints in the notifications section when system notifications are disabled
- macOS permission status check indicator

### Fixed
- Notification permission request for a background app
- “Request” and “Settings…” buttons in notification settings
- Resource loading inside the `.app` bundle

### Changed
- Notification permission is requested when the option is enabled in settings, not at app launch

### Improved
- Opens the Cursor Checker notifications pane in macOS System Settings

## [1.3.6] - 2026-07-17

### Fixed
- Display and refresh of info lines in the menu bar dropdown

### Changed
- App secrets (Telegram bot token and Cursor token) are now stored in a local `secrets.json` file instead of Keychain; data is migrated automatically on first launch

## [1.3.5] - 2026-07-17

### Added
- Standard macOS app menu in the menu bar: About, Hide, Quit, and ⌘Q to quit

### Fixed
- Clean app termination: settings window and open panels (changelog, license) close before quit
- Keychain storage: existing entries are updated in place without unnecessary delete/recreate cycles

### Changed
- Changelog and license agreement open as panels inside the settings window instead of separate pop-up windows

## [1.3.4] - 2026-07-17

### Added
- “Warning icon” setting — toggle ⚠️ in the menu bar title when the daily threshold is exceeded
- “Check” button in the updates block when a new version is already available

### Fixed
- System notification permission request — the app activates before the dialog and the request works correctly
- Opening macOS notification settings — the app activates before opening

### Changed
- Poll interval hint now mentions battery impact
- Notifications section renamed: “macOS banners” → “System notifications”
- macOS permission controls no longer depend on whether system notifications are enabled

### Improved
- “Request” and “Settings…” buttons for notification permission are always available
- Notification permission request includes support for badge icons on the app icon

## [1.3.3] - 2026-07-17

### Added
- App icon in the Dock — clicking it opens settings
- Structured changelog view with versions, dates, and sections

### Fixed
- Loading icon, license, and changelog in the built app
- Auto-connect to Cursor after an explicit token revoke
- Relaunch when multiple app copies from different folders are open at once
- Telegram bot token is not prefilled when Telegram notifications are disabled

### Changed
- Cursor account email is stored in settings, not in Keychain
- In About, changelog moved into the updates block

### Improved
- Keychain caching for faster access to stored data
- Settings window height and About section layout

## [1.3.2] - 2026-07-17

### Added
- Changelog in the About section
- View available update notes (“What’s new”) in settings

### Fixed
- Usage polling restarts only when the poll interval changes, not on every settings change
- Usage state is saved only when there are actual changes

### Changed
- Bot token, Chat ID, and custom intervals apply settings with a short debounce while typing

### Improved
- Poll timer is more resource-efficient
