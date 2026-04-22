import BilineOperations
import Carbon
import Foundation

struct AgentDebugLogEntry: Encodable {
    let sessionId: String
    let runId: String
    let hypothesisId: String
    let location: String
    let message: String
    let data: [String: String]
    let timestamp: Int64
}

enum AgentDebugLogger {
    private static let logURL = URL(
        fileURLWithPath: "/Users/minidudu/Documents/Clone/BilineIME/.cursor/debug-fd6de6.log"
    )

    static func write(
        runId: String = "pre-fix-host-smoke",
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String]
    ) {
        let entry = AgentDebugLogEntry(
            sessionId: "fd6de6",
            runId: runId,
            hypothesisId: hypothesisId,
            location: location,
            message: message,
            data: data,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        let encoder = JSONEncoder()
        guard let payload = try? encoder.encode(entry) else { return }
        do {
            let directory = logURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: logURL.path) {
                try Data().write(to: logURL, options: [.atomic])
            }
            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload + Data([0x0A]))
        } catch {
            // Debug logging must never break the smoke harness.
        }
    }
}

enum HostSmokeScenario: String, CaseIterable {
    case candidatePopup = "candidate-popup"
    case browse
    case commit
    case settingsRefresh = "settings-refresh"
    case full
}

enum HostSmokeError: Error, LocalizedError {
    case preflightFailed(String)
    case telemetryTimeout(String)
    case assertionFailed(String)
    case automationFailed(String)

    var errorDescription: String? {
        switch self {
        case .preflightFailed(let message),
            .telemetryTimeout(let message),
            .assertionFailed(let message),
            .automationFailed(let message):
            return message
        }
    }
}

struct HostSmokeKeyAction {
    let keyCode: Int
    let modifiers: [String]

    static let browseDown = HostSmokeKeyAction(keyCode: 24, modifiers: [])
    static let moveRight = HostSmokeKeyAction(keyCode: 124, modifiers: [])
    static let commit = HostSmokeKeyAction(keyCode: 36, modifiers: [])
    static let selectCandidate1 = HostSmokeKeyAction(keyCode: 18, modifiers: [])
    static let selectCandidate2 = HostSmokeKeyAction(keyCode: 19, modifiers: [])
}

enum HostSmokeKeyboardMap {
    static let keyCodes: [Character: HostSmokeKeyAction] = [
        "a": HostSmokeKeyAction(keyCode: 0, modifiers: []),
        "b": HostSmokeKeyAction(keyCode: 11, modifiers: []),
        "c": HostSmokeKeyAction(keyCode: 8, modifiers: []),
        "d": HostSmokeKeyAction(keyCode: 2, modifiers: []),
        "e": HostSmokeKeyAction(keyCode: 14, modifiers: []),
        "f": HostSmokeKeyAction(keyCode: 3, modifiers: []),
        "g": HostSmokeKeyAction(keyCode: 5, modifiers: []),
        "h": HostSmokeKeyAction(keyCode: 4, modifiers: []),
        "i": HostSmokeKeyAction(keyCode: 34, modifiers: []),
        "j": HostSmokeKeyAction(keyCode: 38, modifiers: []),
        "k": HostSmokeKeyAction(keyCode: 40, modifiers: []),
        "l": HostSmokeKeyAction(keyCode: 37, modifiers: []),
        "m": HostSmokeKeyAction(keyCode: 46, modifiers: []),
        "n": HostSmokeKeyAction(keyCode: 45, modifiers: []),
        "o": HostSmokeKeyAction(keyCode: 31, modifiers: []),
        "p": HostSmokeKeyAction(keyCode: 35, modifiers: []),
        "q": HostSmokeKeyAction(keyCode: 12, modifiers: []),
        "r": HostSmokeKeyAction(keyCode: 15, modifiers: []),
        "s": HostSmokeKeyAction(keyCode: 1, modifiers: []),
        "t": HostSmokeKeyAction(keyCode: 17, modifiers: []),
        "u": HostSmokeKeyAction(keyCode: 32, modifiers: []),
        "v": HostSmokeKeyAction(keyCode: 9, modifiers: []),
        "w": HostSmokeKeyAction(keyCode: 13, modifiers: []),
        "x": HostSmokeKeyAction(keyCode: 7, modifiers: []),
        "y": HostSmokeKeyAction(keyCode: 16, modifiers: []),
        "z": HostSmokeKeyAction(keyCode: 6, modifiers: []),
        " ": HostSmokeKeyAction(keyCode: 49, modifiers: []),
        "=": HostSmokeKeyAction(keyCode: 24, modifiers: []),
        "]": HostSmokeKeyAction(keyCode: 30, modifiers: []),
        "-": HostSmokeKeyAction(keyCode: 27, modifiers: []),
        "[": HostSmokeKeyAction(keyCode: 33, modifiers: []),
        "\t": HostSmokeKeyAction(keyCode: 48, modifiers: []),
    ]
}

/// Thin Carbon wrapper used by the harness once the readiness checker has
/// confirmed that switching the input source is safe. Readiness classification
/// itself lives in `BilineInputSourceReadinessChecker` and is shared with the
/// diagnostics path.
enum InputSourceController {
    static func currentInputSourceID() -> String? {
        CarbonInputSourceQuery().currentInputSourceID()
    }

    static func select(inputSourceID: String) throws {
        guard let source = findSource(inputSourceID) else {
            throw HostSmokeError.preflightFailed(
                "Missing input source \(inputSourceID). Run `bilinectl smoke-host dev --check` for a readiness report."
            )
        }
        let result = TISSelectInputSource(source)
        guard result == noErr else {
            throw HostSmokeError.preflightFailed(
                "TISSelectInputSource failed for \(inputSourceID) with status \(result)."
            )
        }
    }

    private static func findSource(_ inputSourceID: String) -> TISInputSource? {
        let list =
            (TISCreateInputSourceList(nil, true).takeRetainedValue() as NSArray)
            as! [TISInputSource]
        return list.first(where: { source in
            guard let unmanaged = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            else { return false }
            let value = Unmanaged<AnyObject>.fromOpaque(unmanaged).takeUnretainedValue() as? String
            return value == inputSourceID
        })
    }
}
