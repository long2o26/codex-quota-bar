#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CodexQuotaBar"
APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
ZIP="$DIST/$APP_NAME.zip"

"$ROOT/scripts/build.sh" >/dev/null
rm -rf "$DIST"
mkdir -p "$DIST"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP" "$ZIP"
echo "$ZIP"
