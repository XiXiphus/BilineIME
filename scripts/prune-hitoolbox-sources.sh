#!/bin/bash
set -euo pipefail

TMP_PLIST="$(mktemp /tmp/biline-hitoolbox.XXXXXX.plist)"
cleanup() {
  rm -f "$TMP_PLIST"
}
trap cleanup EXIT

defaults export com.apple.HIToolbox "$TMP_PLIST" >/dev/null 2>&1 || exit 0

swift - "$TMP_PLIST" <<'EOF'
import Foundation

let bundleIDs = Set([
    "io.github.xixiphus.inputmethod.BilineIME.dev",
    "io.github.xixiphus.inputmethod.BilineIME"
])

let inputModes = Set([
    "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin",
    "io.github.xixiphus.inputmethod.BilineIME.pinyin"
])

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)
guard let plist = try PropertyListSerialization.propertyList(from: data, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary else {
    exit(0)
}

let keys = [
    "AppleEnabledInputSources",
    "AppleSelectedInputSources",
    "AppleInputSourceHistory"
]

func shouldRemove(_ entry: Any) -> Bool {
    guard let dict = entry as? NSDictionary else { return false }
    let bundleID = (dict["Bundle ID"] as? String) ?? ""
    let inputMode = (dict["Input Mode"] as? String) ?? ""
    if bundleIDs.contains(bundleID) || inputModes.contains(inputMode) {
        return true
    }
    return bundleID.contains("io.github.xixiphus.inputmethod.BilineIME")
        || inputMode.contains("io.github.xixiphus.inputmethod.BilineIME")
}

var changed = false

for key in keys {
    guard let array = plist[key] as? [Any] else { continue }
    let filtered = array.filter { !shouldRemove($0) }
    if filtered.count != array.count {
        plist[key] = filtered
        changed = true
    }
}

if changed {
    let updated = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try updated.write(to: url)
    print("pruned")
}
EOF

defaults import com.apple.HIToolbox "$TMP_PLIST"

killall cfprefsd >/dev/null 2>&1 || true
