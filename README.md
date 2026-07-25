<p align="center">
  <img src="Resources/AppIcon-1024-rounded.png" alt="Cursor Checker" width="128">
</p>

<h1 align="center">Cursor Checker</h1>
<p align="center"><b>Track your Cursor quota from the menu bar</b><br></p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#features">Features</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#development">Development</a> ·
  <a href="#license">License</a>
</p>

<p align="center">
  <a href="https://github.com/cursor-checker/macos/releases" target="_blank" rel="noopener noreferrer"><img src="https://img.shields.io/github/v/release/cursor-checker/macos?label=release&color=orange" alt="Release"></a>
  <img src="https://img.shields.io/badge/license-PolyForm%20NC-blue" alt="License">
  <img src="https://img.shields.io/badge/macOS-15%2B-black?logo=apple" alt="macOS 15+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white" alt="Swift 5.9">
</p>

---

## Install

**Requirements:** macOS 15.0+, [Cursor](https://cursor.com) signed in.

### Pre-built app (recommended)

1. Download `CursorChecker-<version>.zip` or `.dmg` from [**Releases**](https://github.com/cursor-checker/macos/releases).
2. Move `CursorChecker.app` to **Applications**.
3. Open the app → **Settings → Connection** → **Connect Cursor**.
4. Allow notifications when macOS asks.

Optional: **Launch at login** in **Settings → About** (`SMAppService`, no LaunchAgent).

The app auto-updates from [macos](https://github.com/cursor-checker/macos) (`.zip` with `CursorChecker.app` inside).

## Features

- **Menu bar summary** — cycle %, daily spend, remaining quota, auto/API split, cycle end date
- **Daily burn alerts** — +5%, +10%, +15% of monthly quota per day (configurable step)
- **Manual connection** — no Cursor data is read until you connect in Settings
- **macOS notifications** — tap a banner to open Overview
- **Telegram** — optional bot alerts; token stored in Keychain
- **Settings window** — connection, thresholds, poll interval, notifications, journal, changelog
- **CLI** — `--once` and `--test` for scripts and cron

## How it works

1. **You connect manually.** On first launch nothing is read. **Settings → Connection → Connect** loads the local session token.
2. **Local token** from Cursor's database:
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` (`cursorAuth/accessToken`).
3. **Polls every *N* minutes:**
   `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`
   Token goes only to Cursor servers.
4. **Cycle usage** from `planUsage.totalPercentUsed`.
5. **Daily baseline** — each calendar day starts a fresh baseline; *spent today* = current % − morning %.
6. **Thresholds** — alerts at each multiple of `dailyThresholdPercent` (default **5%**).

> **Unofficial API.** Same endpoint as Cursor's dashboard; may change without notice. Keep Cursor signed in so tokens stay fresh.

### Usage

| Menu | Opens |
|------|-------|
| **Overview** | Stats, breakdown, spend today |
| **Settings** | Connection, thresholds, Telegram, about |

```bash
./.build/release/CursorChecker --once   # one-shot check + notify if needed
./.build/release/CursorChecker --test   # test all notification channels
```

## Configuration

Use **Settings**, or edit `~/Library/Application Support/cursor-checker/config.json`:

```jsonc
{
  "pollIntervalMinutes": 15,
  "dailyThresholdPercent": 5,
  "macNotificationsEnabled": true,
  "telegram": {
    "enabled": false,
    "botToken": "",
    "chatId": ""
  }
}
```

| Field | Description |
|-------|-------------|
| `pollIntervalMinutes` | Poll interval (`0.25` = 15 s, `15` = 15 min) |
| `dailyThresholdPercent` | Alert every N% of monthly quota spent in one day |
| `macNotificationsEnabled` | macOS banners |
| `telegram.*` | Bot alerts (`botToken` migrates to Keychain on launch) |

Files are created with mode `0600` / `0700`.

<details>
<summary><b>Telegram setup</b></summary>

1. [@BotFather](https://t.me/BotFather) → `/newbot` → copy token.
2. Message your bot once.
3. Chat ID from `getUpdates` or [@userinfobot](https://t.me/userinfobot).
4. Set token + chat ID in Settings; enable Telegram.
5. Test: **Settings → Notifications → Send** or `CursorChecker --test`.

Bot token is stored in Keychain (`com.nokk3r.cursorchecker`), not in `config.json`.

```bash
security delete-generic-password -s com.nokk3r.cursorchecker
```

</details>

<details>
<summary><b>Other data files</b></summary>

| File | Purpose |
|------|---------|
| `state.json` | Daily baseline & fired thresholds |
| `journal.json` | Activity log (if enabled) |

</details>

## Development

```bash
git clone https://github.com/cursor-checker/macos.git
cd macos

swift build -c release --product CursorChecker
.build/release/CursorChecker --once
```

```bash
swift run CursorChecker
```

> `swift build` outputs a CLI binary, not a `.app` bundle. Use a [release build](https://github.com/cursor-checker/macos/releases) for full menu bar + notifications.

See [CONTRIBUTING.md](CONTRIBUTING.md) · [Report a bug](https://github.com/cursor-checker/macos/issues)

## Uninstall

**In app:** Settings → About → **Delete application**.

```bash
rm -f ~/Library/LaunchAgents/com.nokk3r.cursorchecker.plist
rm -rf ~/Applications/CursorChecker.app
rm -rf ~/Library/Application\ Support/cursor-checker
rm -rf ~/Library/Application\ Support/CursorChecker
security delete-generic-password -s com.nokk3r.cursorchecker 2>/dev/null || true
```

## License

Source code: [PolyForm Noncommercial License 1.0.0](LICENSE).

| Use | Allowed |
|-----|---------|
| Personal, educational, hobby, qualifying nonprofits | Yes |
| Selling the app, SaaS, white-label | [Commercial license](COMMERCIAL.md) required |

Not OSI open source. © 2026 [Rete studio](https://github.com/cursor-checker)

## Disclaimer

**Cursor Checker** is not affiliated with Anysphere / Cursor. Cursor® is a trademark of Anysphere. Usage data uses an **unofficial** API that may break when Cursor updates their backend.
