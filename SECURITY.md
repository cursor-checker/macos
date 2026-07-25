# Security policy

## Supported versions

Security fixes are provided for the **latest release** published in
[cursor-checker/macos](https://github.com/cursor-checker/macos).
Older versions may not receive patches.

| Version | Supported |
| ------- | --------- |
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

If you believe you have found a security vulnerability in Cursor Checker,
please report it responsibly.

**Email:** [nokk3r@gmail.com](mailto:nokk3r@gmail.com)

Please include:

- A description of the issue and its potential impact
- Steps to reproduce
- Affected version(s)
- Any proof-of-concept or relevant details

### What to expect

- We aim to acknowledge reports within a few business days.
- We will work on a fix or mitigation and coordinate disclosure when appropriate.
- Please do **not** open a public GitHub issue for undisclosed security problems.

### Sensitive data

Cursor Checker reads a local Cursor session token and may store Telegram settings
in the macOS Keychain. When reporting issues, do **not** send:

- Cursor `accessToken` values
- Telegram bot tokens
- `config.json` / Keychain exports with secrets

## Out of scope

The following are generally **not** treated as vulnerabilities in this project:

- Issues caused by changes to Cursor's unofficial API or local database format
- Social engineering or physical access to an unlocked Mac
- Misconfiguration by the user (e.g. sharing a Telegram bot token)

## Safe harbor

We appreciate good-faith security research conducted in line with this policy.
