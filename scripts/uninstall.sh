#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.long.codex-quota-bar.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/CodexQuotaBar.app"
osascript -e 'tell application "CodexQuotaBar" to quit' 2>/dev/null || true
echo "uninstalled"
