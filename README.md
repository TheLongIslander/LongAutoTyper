# LongAutoTyper

A macOS menu bar app that auto-types text with configurable delay and countdown.

## V1 Features

- Global hotkey `F12` (and `fn+F12`) to type current clipboard text.
- Main emergency stop hotkey: `Control + Option + Command + .`.
- Manual text box in a small window with a `Type Manual Text` button.
- Configurable per-character delay (default `0.02s`).
- Configurable start countdown (default `5s`).
- Hotkey path starts immediately (no countdown).
- Auto-pauses typing when you switch to another app, and resumes when focus returns to the original target app.
- Pressing `Delete`/`Backspace` while typing can also stop the current run (requires Input Monitoring permission).
- Menu bar controls to open window, start clipboard typing, stop typing, and quit.
- Background-friendly behavior via menu bar extra.
- In-app `Check for Updates...` menu action (Sparkle feed-based updater).

## Requirements

- macOS 13+
- Xcode 26+ command line tools (Swift 6.2)

## Run

```bash
swift run
```

The app will launch with a window and a menu bar icon.

## Build / Package Commands

### 1) Build only the app (`.app`)

Use this when you just want a double-clickable app for yourself.

```bash
./scripts/build_app_bundle.sh --version 0.1.0
```

Output:

- `dist/LongAutoTyper.app`

### 2) Build release artifacts for sharing (`.app` + `.zip` + `.dmg` + `.pkg`)

Use this when you want files to upload/share with other users.

```bash
./scripts/package_macos.sh --version 0.1.0
```

Outputs:

- `dist/LongAutoTyper.app`
- `dist/LongAutoTyper.zip`
- `dist/LongAutoTyper.dmg`
- `dist/LongAutoTyper.pkg`

By default this is a true universal build (`x86_64` + `arm64`).
Use `--arch` flags only if you want a single-architecture artifact.

The generated `.pkg` is configured as non-relocatable and installs to:

- `/Applications/LongAutoTyper.app`

After installing the `.pkg`, you should find it in Finder at:

- `Applications/LongAutoTyper.app`

### Quick decision

- `build_app_bundle.sh`: app only
- `package_macos.sh`: app + zip + installer/distribution files

### Useful flags (both scripts)

- `--configuration debug|release`
- `--arch x86_64` or `--arch arm64` (repeatable; default builds both for universal)

Extra flags for `package_macos.sh` only:

- `--skip-zip`
- `--skip-dmg`
- `--skip-pkg`

Sparkle-related flags (both scripts):

- `--feed-url https://your-domain/appcast.xml`
- `--sparkle-public-key YOUR_PUBLIC_ED25519_KEY`
- `--disable-automatic-update-checks`

Equivalent env vars:

- `SPARKLE_FEED_URL`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_AUTOMATIC_CHECKS=0|1`

## Free In-App Update Pipeline (No Apple $99 Required)

This project now supports Sparkle-based update checks with a hosted appcast feed.

### 1) Generate Sparkle keys once

Install Sparkle tools and run:

```bash
generate_keys
```

Save:

- the public key in your build command (`SPARKLE_PUBLIC_ED_KEY` or `--sparkle-public-key`)
- the private key securely (used by `generate_appcast` for signing releases)

### 2) Build release artifacts with feed metadata

```bash
SPARKLE_FEED_URL="https://YOUR_USERNAME.github.io/LongAutoTyper/appcast.xml" \
SPARKLE_PUBLIC_ED_KEY="YOUR_PUBLIC_ED25519_KEY" \
./scripts/package_macos.sh --version 0.1.0
```

### 3) Generate appcast

From your release artifacts directory (typically `dist/`), generate a signed appcast:

```bash
generate_appcast dist/
```

That produces an `appcast.xml` describing available updates.

### 4) Host artifacts + appcast over HTTPS

Host at least:

- `LongAutoTyper.zip` (or another Sparkle-supported artifact)
- `appcast.xml`

GitHub Pages is a free option for hosting both.

### 5) User update flow

In the app menu bar panel, use `Check for Updates...`.
If a newer version exists in the appcast, Sparkle prompts and installs it.

## Security/UX Notes Without Paid Apple Signing

- This setup is free, but Gatekeeper prompts are stricter for unsigned/notarized apps.
- Sparkle update integrity still relies on your EdDSA signature (`SUPublicEDKey`), so do not share your private key.

## App Icon

To use a custom app icon, add one of these files:

- `Sources/LongAutoTyper/Resources/AppIcon.icns` (recommended)
- `Sources/LongAutoTyper/Resources/AppIcon.png`

Then rebuild and run again.

## Permissions

To emit keystrokes into other apps, macOS requires **Accessibility** permission:

1. Open `System Settings`.
2. Go to `Privacy & Security` -> `Accessibility`.
3. Enable permission for the built app process.

If permission is missing, the app prompts when typing is requested.

For global `Delete`/`Backspace` stop detection, macOS may also require **Input Monitoring** permission for the app.

## Behavior Notes

- Hotkey path always types from clipboard.
- Manual text typing is button-triggered from the app window.
- `Stop` cancels countdown/typing immediately.

## Distribution Notes

- Unsigned builds may show Gatekeeper warnings on other machines.

### Running Unsigned Builds

If macOS blocks launch with "cannot be opened because Apple cannot check it for malicious software":

1. Try right-clicking the app and choose `Open`, then confirm.
2. If still blocked, open `System Settings` -> `Privacy & Security`.
3. In the Security section, click `Open Anyway` for `LongAutoTyper`.
4. Launch the app again and confirm `Open`.

### If packaging fails with `Permission denied` in `dist/LongAutoTyper.app`

This usually means the existing app bundle in `dist/` is owned by `root`.

Run one of:

```bash
sudo chown -R "$(id -un)":staff dist/LongAutoTyper.app
```

or

```bash
sudo rm -rf dist/LongAutoTyper.app
```

Then run the packaging command again.

### If packaging fails with `pkgbuild` argument errors

If you see either of these:

- `--root must be specified in --analyze mode`
- `--component-plist can be used only when a --root is specified`

you are likely running an older script copy. Confirm the current script does not use `--component` or `--component-plist`:

```bash
rg -n "component-plist|--component|--analyze" scripts/package_macos.sh
```

Expected result: no matches.

Then rerun:

```bash
./scripts/package_macos.sh --version 0.1.0
```
