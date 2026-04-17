#!/bin/bash
set -euo pipefail

if [[ -n "${BILINE_DEV_TEAM_ID:-}" ]]; then
  printf '%s\n' "$BILINE_DEV_TEAM_ID"
  exit 0
fi

XCODE_PREFS_PLIST="${HOME}/Library/Preferences/com.apple.dt.Xcode.plist"
if [[ ! -f "$XCODE_PREFS_PLIST" ]]; then
  exit 0
fi

/usr/bin/plutil -p "$XCODE_PREFS_PLIST" 2>/dev/null \
  | /usr/bin/sed -n 's/.*"teamID" => "\(.*\)"/\1/p' \
  | /usr/bin/head -n 1
