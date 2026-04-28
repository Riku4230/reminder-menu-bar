## Install

### Recommended: Build from source

```bash
git clone https://github.com/Riku4230/Hutch.git
cd Hutch
./scripts/build_app.sh --install
```

Requirements: macOS 14+, Swift 5.9+, Xcode Command Line Tools.

### Advanced: Unsigned prebuilt build

The attached `.dmg` is **unsigned and not notarized**. macOS Gatekeeper may block it on first launch — if you choose to continue, go to **System Settings → Privacy & Security → "Open Anyway"**. Only do this if you trust this build.

For maximum safety, review the source code and build Hutch locally instead.

### Verifying the checksum

A `Hutch-*.dmg.sha256` file is attached to this release. From the directory where you downloaded the `.dmg`:

```bash
shasum -a 256 -c Hutch-*.dmg.sha256
```

You should see `OK`.

The Homebrew Cask pins the same SHA256, so `brew install --cask hutch` verifies integrity automatically.

## Security notes

- API keys are stored in macOS Keychain only.
- AI requests are sent directly to the selected provider — no proxy server.
- Reminder data stays inside Apple Reminders / iCloud.
- No external runtime dependencies (Swift Package Manager + system SQLite only).

See [SECURITY.md](https://github.com/Riku4230/Hutch/blob/main/SECURITY.md) for the full security stance and how to report vulnerabilities.

---
