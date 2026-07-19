# CodexQuotaBar

A tiny macOS menu bar widget that shows your Codex quota at a glance.

![CodexQuotaBar menu bar screenshot](docs/codex-quota-bar-menu.png)

CodexQuotaBar queries the locally installed Codex CLI for current rate limits and renders them in the macOS menu bar. If the live query is temporarily unavailable, it keeps the last successful value and falls back to local session logs in `~/.codex/sessions/**/*.jsonl`.

```text
5h  [bars]  99%  04:43
7d  [bars]  81%  6月29日
```

## Features

- Two-row quota display for the short window and weekly window.
- Color-coded bars: green `>60`, orange `20...60`, red `<20`.
- Reset time reported by Codex.
- Uses your existing local Codex installation and login; no extra API key or third-party service.
- Refreshes every 15 seconds without blocking the menu bar UI.
- Starts automatically after login through a user LaunchAgent.
- Restarts after abnormal exits, while a normal in-app Quit stays quit.
- Stable menu bar identity so macOS keeps its visible position after restarts.

## Install

### Option 1: Download Release

Download `CodexQuotaBar.zip` from the [latest release](https://github.com/long2o26/codex-quota-bar/releases/latest), unzip it, and open `CodexQuotaBar.app`.

If macOS blocks the unsigned app:

```bash
xattr -dr com.apple.quarantine CodexQuotaBar.app
open CodexQuotaBar.app
```

### Option 2: Build From Source

Requires macOS, a working Codex CLI login, and Xcode Command Line Tools.

```bash
git clone https://github.com/long2o26/codex-quota-bar.git
cd codex-quota-bar
./scripts/install.sh
```

This builds the app, installs it to `~/Applications/CodexQuotaBar.app`, and registers:

```text
~/Library/LaunchAgents/com.long.codex-quota-bar.plist
```

## Display Modes

Open the menu bar item to switch display mode:

- `Detail`: full v0.1.1-style two-row UI.
- `Auto`: prefer detail, fall back when the item is too wide.
- `Compact`: short text fallback for crowded menu bars.

## Commands

Build:

```bash
./scripts/build.sh
open ./build/CodexQuotaBar.app
```

Install or update the LaunchAgent:

```bash
./scripts/install.sh
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

## Troubleshooting

If the menu bar item does not appear or refresh, check the value returned through Codex:

```bash
./build/CodexQuotaBar.app/Contents/MacOS/CodexQuotaBar --print-once
```

If the process is running but the item disappears after restart, older builds may have been treated by macOS as an anonymous status item and placed in a hidden menu bar area. Current builds set a stable `autosaveName` so macOS can remember the visible position after restart.

If there are two menu bar items, quit the temporary build and keep the installed app:

```bash
pkill -f "/build/CodexQuotaBar.app"
```

If you want the full two-row UI but your menu bar manager hides it, switch to `Display: Detail` and drag the item into the visible area once. macOS should remember it afterwards.
