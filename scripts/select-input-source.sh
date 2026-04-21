#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <current|exists|dump-bundle> [argument]" >&2
  exit 1
fi

COMMAND="$1"
ARGUMENT="${2:-}"

swift - "$COMMAND" "$ARGUMENT" <<'EOF'
import Carbon
import Foundation

func value(_ source: TISInputSource, _ key: CFString) -> Any? {
    guard let unmanaged = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(unmanaged).takeUnretainedValue()
}

func findSource(_ inputSourceID: String) -> TISInputSource? {
    let list = (TISCreateInputSourceList(nil, true).takeRetainedValue() as NSArray) as! [TISInputSource]
    return list.first(where: {
        (value($0, kTISPropertyInputSourceID) as? String) == inputSourceID
    })
}

func dump(_ source: TISInputSource) {
    let id = value(source, kTISPropertyInputSourceID) as? String ?? ""
    let name = value(source, kTISPropertyLocalizedName) as? String ?? ""
    let category = value(source, kTISPropertyInputSourceCategory) as? String ?? ""
    let type = value(source, kTISPropertyInputSourceType) as? String ?? ""
    let enabled = value(source, kTISPropertyInputSourceIsEnabled) as? Bool ?? false
    let selectable = value(source, kTISPropertyInputSourceIsSelectCapable) as? Bool ?? false
    let selected = value(source, kTISPropertyInputSourceIsSelected) as? Bool ?? false
    let bundleID = value(source, kTISPropertyBundleID) as? String ?? ""
    print("id=\(id) name=\(name) category=\(category) type=\(type) enabled=\(enabled) selectable=\(selectable) selected=\(selected) bundle=\(bundleID)")
}

guard CommandLine.arguments.count >= 2 else {
    fputs("missing command\n", stderr)
    exit(1)
}

let command = CommandLine.arguments[1]
let argument = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : ""

switch command {
case "current":
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let id = value(current, kTISPropertyInputSourceID) as? String ?? ""
    guard !id.isEmpty else {
        exit(2)
    }
    print(id)
case "exists":
    guard !argument.isEmpty else {
        fputs("missing input source id\n", stderr)
        exit(1)
    }
    guard findSource(argument) != nil else {
        exit(4)
    }
    print("found")
case "dump-bundle":
    guard !argument.isEmpty else {
        fputs("missing bundle id\n", stderr)
        exit(1)
    }
    let list = (TISCreateInputSourceList(nil, true).takeRetainedValue() as NSArray) as! [TISInputSource]
    for source in list {
        let bundleID = value(source, kTISPropertyBundleID) as? String ?? ""
        if bundleID == argument {
            dump(source)
        }
    }
default:
    fputs("unsupported command: \(command)\n", stderr)
    exit(1)
}
EOF
