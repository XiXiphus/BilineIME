#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <current|exists|dump-bundle|readiness> [argument]" >&2
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
case "readiness":
    let inputSourceID = argument.isEmpty
        ? "io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"
        : argument
    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    let currentID = value(current, kTISPropertyInputSourceID) as? String ?? ""
    print("input_source_id=\(inputSourceID)")
    print("current_input_source=\(currentID)")
    guard let source = findSource(inputSourceID) else {
        print("source_registered=false")
        print("state=source-missing-or-bundle-missing")
        print("ready=false")
        print("hint=Run `bilinectl smoke-host dev --check` for a full readiness report including bundle installation state.")
        exit(0)
    }
    let enabled = value(source, kTISPropertyInputSourceIsEnabled) as? Bool ?? false
    let selectable = value(source, kTISPropertyInputSourceIsSelectCapable) as? Bool ?? false
    let selected = value(source, kTISPropertyInputSourceIsSelected) as? Bool ?? false
    let name = value(source, kTISPropertyLocalizedName) as? String ?? ""
    print("source_registered=true")
    print("source_localized_name=\(name)")
    print("source_enabled=\(enabled)")
    print("source_selectable=\(selectable)")
    print("source_selected=\(selected)")
    let state: String
    if !enabled {
        state = "source-disabled"
    } else if !selectable {
        state = "source-not-selectable"
    } else if currentID == inputSourceID || selected {
        state = "ready"
    } else {
        state = "source-not-selected"
    }
    let isReady = state == "ready" || state == "source-not-selected"
    print("state=\(state)")
    print("ready=\(isReady)")
    print("hint=Run `bilinectl smoke-host dev --check` for the full report (includes bundle install state).")
default:
    fputs("unsupported command: \(command)\n", stderr)
    exit(1)
}
EOF
