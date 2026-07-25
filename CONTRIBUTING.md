# Contributing to Cursor Checker

Thank you for your interest in Cursor Checker. This project is maintained by
[Rete studio](https://github.com/cursor-checker).

## Before you start

- Read the [README](README.md) for how the app works and how to build it.
- Source code is licensed under the
  [PolyForm Noncommercial License 1.0.0](LICENSE). Personal, hobby, educational,
  and other noncommercial use is welcome.
- **Commercial use** (selling the app, paid SaaS, white-label, and similar) requires
  a separate agreement — see [COMMERCIAL.md](COMMERCIAL.md).

By submitting a contribution, you agree that your contribution is licensed under
the same [PolyForm Noncommercial License 1.0.0](LICENSE) and that Rete studio may
use it in the project.

## How to contribute

### Bug reports

Open a [bug report](https://github.com/cursor-checker/macos/issues/new?template=bug_report.yml)
and include:

- macOS version
- Cursor Checker version (About → version string)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or screenshots

Do **not** include Cursor session tokens, Telegram bot tokens, or other secrets.

### Feature requests

Open a [feature request](https://github.com/cursor-checker/macos/issues/new?template=feature_request.yml)
and describe the problem you are trying to solve, not only the solution you prefer.

### Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep changes focused — one logical change per PR when possible.
3. Match existing code style and naming in the Swift sources.
4. Test locally:

   ```bash
   swift build -c release --product CursorChecker
   ```

5. Update `CHANGELOG.md` / `CHANGELOG.en.md` only if the maintainers ask or if the
   change is user-visible and release notes are being prepared for that release.
6. Fill out the pull request template completely.

We may ask for revisions before merging. Not every PR will be accepted, especially
if it conflicts with project scope or maintenance goals.

## Development notes

- Swift toolchain from Xcode or Command Line Tools is required.
- Do not commit `.env`, tokens, or local config/state files.
- The app uses an **unofficial** Cursor API endpoint; behavior may change when
  Cursor updates their backend.

## Questions

For commercial licensing: [nokk3r@gmail.com](mailto:nokk3r@gmail.com).

For general questions, open a GitHub issue or discussion when available.
