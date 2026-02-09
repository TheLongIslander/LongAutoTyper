# LongAutoTyper

A macOS menu bar app that auto-types text with configurable delay and countdown.

## V1 Features

- Global hotkey `Cmd + Shift + V` to type current clipboard text.
- Manual text box in a small window with a `Type Manual Text` button.
- Configurable per-character delay (default `0.15s`).
- Configurable start countdown (default `5s`).
- Menu bar controls to open window, start clipboard typing, stop typing, and quit.
- Background-friendly behavior via menu bar extra.

## Requirements

- macOS 13+
- Xcode 26+ command line tools (Swift 6.2)

## Run

```bash
swift run
```

The app will launch with a window and a menu bar icon.

## Permissions

To emit keystrokes into other apps, macOS requires **Accessibility** permission:

1. Open `System Settings`.
2. Go to `Privacy & Security` -> `Accessibility`.
3. Enable permission for the built app process.

If permission is missing, the app prompts when typing is requested.

## Behavior Notes

- Hotkey path always types from clipboard.
- Manual text typing is button-triggered from the app window.
- `Stop` cancels countdown/typing immediately.
