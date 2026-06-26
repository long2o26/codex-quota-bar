#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexQuotaBar"
APP_SRC="$ROOT/build/$APP_NAME.app"
APP_DST="$HOME/Applications/$APP_NAME.app"
APP_EXEC="$APP_DST/Contents/MacOS/$APP_NAME"
PLIST="$HOME/Library/LaunchAgents/com.long.codex-quota-bar.plist"

"$ROOT/scripts/build.sh" >/dev/null
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.long.codex-quota-bar</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_EXEC</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.long.codex-quota-bar"
echo "installed: $APP_DST"
