#!/usr/bin/env swift

import ApplicationServices
import Foundation

struct Arguments {
    var key: String
    var activateTarget: String?
    var useSystemEvents = false
    var shift = false
    var control = false
    var option = false
    var command = false
    var function = false
    var repeatCount = 1
    var delayMs = 25
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case unknownKey(String)
    case invalidValue(String)
    case sourceUnavailable
    case eventUnavailable(String)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .unknownKey(let key):
            return "Unknown key: \(key)"
        case .invalidValue(let value):
            return "Invalid value: \(value)"
        case .sourceUnavailable:
            return "Unable to create CGEvent source. Check accessibility/input-monitoring permissions."
        case .eventUnavailable(let name):
            return "Unable to create keyboard event for \(name)."
        }
    }
}

private let keyCodes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
    "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
    "equal": 24, "=": 24,
    "9": 25, "7": 26,
    "minus": 27, "-": 27,
    "8": 28, "0": 29,
    "rightbracket": 30, "]": 30,
    "o": 31, "u": 32,
    "leftbracket": 33, "[": 33,
    "i": 34, "p": 35,
    "return": 36, "enter": 36,
    "l": 37, "j": 38,
    "quote": 39, "'": 39,
    "k": 40,
    "semicolon": 41, ";": 41,
    "backslash": 42, "\\": 42,
    "comma": 43, ",": 43,
    "slash": 44, "/": 44,
    "n": 45, "m": 46,
    "period": 47, ".": 47,
    "tab": 48,
    "space": 49,
    "grave": 50, "`": 50,
    "delete": 51, "backspace": 51,
    "escape": 53, "esc": 53,
    "left": 123, "arrowleft": 123,
    "right": 124, "arrowright": 124,
    "down": 125, "arrowdown": 125,
    "up": 126, "arrowup": 126,
]

func parseArguments() throws -> Arguments {
    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    guard let first = iterator.next() else {
        throw CLIError.usage(
            """
            Usage: ./scripts/press-macos-key.swift <key> [--shift] [--control] [--option] [--command] [--fn] [--repeat N] [--delay-ms N]
            Example: ./scripts/press-macos-key.swift equal
            Example: ./scripts/press-macos-key.swift 9 --shift
            """
        )
    }

    var parsed = Arguments(key: first.lowercased())

    while let argument = iterator.next() {
        switch argument {
        case "--shift":
            parsed.shift = true
        case "--system-events":
            parsed.useSystemEvents = true
        case "--control":
            parsed.control = true
        case "--option":
            parsed.option = true
        case "--command":
            parsed.command = true
        case "--fn":
            parsed.function = true
        case "--repeat":
            guard let value = iterator.next(), let repeatCount = Int(value), repeatCount > 0 else {
                throw CLIError.invalidValue("--repeat")
            }
            parsed.repeatCount = repeatCount
        case "--activate":
            guard let value = iterator.next(), !value.isEmpty else {
                throw CLIError.invalidValue("--activate")
            }
            parsed.activateTarget = value
        case "--delay-ms":
            guard let value = iterator.next(), let delayMs = Int(value), delayMs >= 0 else {
                throw CLIError.invalidValue("--delay-ms")
            }
            parsed.delayMs = delayMs
        default:
            throw CLIError.usage("Unknown argument: \(argument)")
        }
    }

    return parsed
}

func activateTargetIfNeeded(_ target: String) throws {
    let script: String
    if target.contains(".") {
        script = "tell application id \"\(target)\" to activate"
    } else {
        script = "tell application \"\(target)\" to activate"
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw CLIError.invalidValue("--activate \(target)")
    }

    usleep(150_000)
}

func postViaSystemEvents(arguments: Arguments, keyCode: CGKeyCode) throws {
    let target = arguments.activateTarget ?? "System Events"
    try activateTargetIfNeeded(target)

    var modifiers: [String] = []
    if arguments.command { modifiers.append("command down") }
    if arguments.control { modifiers.append("control down") }
    if arguments.option { modifiers.append("option down") }
    if arguments.shift { modifiers.append("shift down") }

    let usingClause = modifiers.isEmpty ? "" : " using {\(modifiers.joined(separator: ", "))}"

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
        "-e",
        """
        tell application "System Events"
          repeat \(arguments.repeatCount) times
            key code \(keyCode)\(usingClause)
            delay \(Double(arguments.delayMs) / 1000.0)
          end repeat
        end tell
        """,
    ]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw CLIError.eventUnavailable(arguments.key)
    }
}

func modifierFlags(for arguments: Arguments) -> CGEventFlags {
    var flags: CGEventFlags = []
    if arguments.shift { flags.insert(.maskShift) }
    if arguments.control { flags.insert(.maskControl) }
    if arguments.option { flags.insert(.maskAlternate) }
    if arguments.command { flags.insert(.maskCommand) }
    if arguments.function { flags.insert(.maskSecondaryFn) }
    return flags
}

func postKey(arguments: Arguments) throws {
    guard let keyCode = keyCodes[arguments.key] else {
        throw CLIError.unknownKey(arguments.key)
    }

    if arguments.useSystemEvents || arguments.key == "delete" || arguments.key == "backspace" {
        try postViaSystemEvents(arguments: arguments, keyCode: keyCode)
        return
    }

    if let target = arguments.activateTarget {
        try activateTargetIfNeeded(target)
    }

    guard let source = CGEventSource(stateID: .combinedSessionState) else {
        throw CLIError.sourceUnavailable
    }

    let flags = modifierFlags(for: arguments)
    let delay = useconds_t(arguments.delayMs * 1000)

    for _ in 0..<arguments.repeatCount {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            throw CLIError.eventUnavailable(arguments.key)
        }
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)

        if delay > 0 {
            usleep(delay)
        }

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw CLIError.eventUnavailable(arguments.key)
        }
        keyUp.flags = flags
        keyUp.post(tap: .cghidEventTap)

        if delay > 0 {
            usleep(delay)
        }
    }
}

do {
    let arguments = try parseArguments()
    try postKey(arguments: arguments)
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
