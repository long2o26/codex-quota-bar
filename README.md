# CodexQuotaBar

A tiny macOS menu bar widget for Codex quota.

It reads local Codex session logs from `~/.codex/sessions/**/*.jsonl` and shows two compact rows:

```text
5h  [bars]  99%  04:43
7d  [bars]  81%  6月29日
```

- `5h`: short quota window
- `7d`: weekly quota window
- bars: green `>60`, orange `20...60`, red `<20`
- right-side time: Codex quota reset time from `rate_limits.*.resets_at`

## Install

### Option 1: Build from source

Requires macOS with Xcode Command Line Tools.

```bash
git clone <repo-url>
cd codex-quota-bar
./scripts/install.sh
```

This builds the app, installs it to `~/Applications/CodexQuotaBar.app`, and registers a user `LaunchAgent` so it starts after login.
The LaunchAgent also restarts the app after abnormal exits, while a normal in-app Quit stays quit.

### Option 2: Download release zip

Download `CodexQuotaBar.zip` from the GitHub Releases page, unzip it, and open `CodexQuotaBar.app`.

If macOS blocks the unsigned app:

```bash
xattr -dr com.apple.quarantine CodexQuotaBar.app
open CodexQuotaBar.app
```

## Commands

Build:

```bash
./scripts/build.sh
open ./build/CodexQuotaBar.app
```

Check parsed quota without opening the menu bar app:

```bash
./build/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --print-once
```

Package a release zip:

```bash
./scripts/package.sh
```

Uninstall:

```bash
./scripts/uninstall.sh
```

## Notes

- The app is local-only. It reads Codex logs; it does not call OpenAI or GitHub.
- The number changes after Codex writes a new `token_count` event.
- The menu bar item has a stable `autosaveName`, so macOS can remember its position after CodexQuotaBar restarts.
- The app is unsigned. Building from source is the smoothest install path.

## Troubleshooting

If the menu bar item does not appear, check whether Codex has written quota logs:

```bash
./build/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --print-once
```

If the process is running but the item disappears after a CodexQuotaBar restart, macOS may have treated an unnamed status item as a new anonymous menu bar icon and placed it in the hidden area. Current versions set a stable status item name so macOS can keep the item in the visible position after restart.

If there are two menu bar items, quit the temporary build and keep the installed app:

```bash
pkill -f "/build/CodexQuotaBar.app"
```
