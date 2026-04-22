import AppKit
import ApplicationServices
import BilineIPC
import BilineOperations
import BilineSettings
import Carbon
import Foundation

private enum HostSmokeScenario: String, CaseIterable {
    case candidatePopup = "candidate-popup"
    case browse
    case commit
    case settingsRefresh = "settings-refresh"
    case full
}

private enum HostSmokeError: Error, LocalizedError {
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

private struct HostSmokeKeyAction {
    let keyCode: Int
    let modifiers: [String]

    static let browseDown = HostSmokeKeyAction(keyCode: 24, modifiers: [])
    static let moveRight = HostSmokeKeyAction(keyCode: 124, modifiers: [])
    static let commit = HostSmokeKeyAction(keyCode: 36, modifiers: [])
    static let selectCandidate1 = HostSmokeKeyAction(keyCode: 18, modifiers: [])
    static let selectCandidate2 = HostSmokeKeyAction(keyCode: 19, modifiers: [])
}

private enum HostSmokeKeyboardMap {
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
private enum InputSourceController {
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

private final class TextEditSmokeHost {
    private let runner: any CommandRunning
    private let fileManager: FileManager

    init(runner: any CommandRunning, fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    func preflight() throws {
        _ = try runAppleScript(
            """
            tell application "System Events"
                return UI elements enabled
            end tell
            """
        )
        _ = try runAppleScript(
            """
            tell application "TextEdit"
                return name
            end tell
            """
        )
    }

    func prepareBlankDocument() throws {
        _ = try runAppleScript(
            """
            tell application "TextEdit"
                if it is running then
                    quit saving no
                end if
            end tell
            delay 0.5
            tell application "TextEdit"
                activate
                make new document
                set text of front document to ""
            end tell
            delay 0.5
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                end tell
            end tell
            """
        )
        try focusTextArea()
        try requireSingleSession()
    }

    func focusTextArea() throws {
        _ = try runAppleScript(
            """
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                    repeat 20 times
                        if exists window 1 then
                            exit repeat
                        end if
                        delay 0.1
                    end repeat
                    repeat 20 times
                        if exists text area 1 of scroll area 1 of window 1 then
                            click text area 1 of scroll area 1 of window 1
                            exit repeat
                        end if
                        delay 0.1
                    end repeat
                end tell
            end tell
            """
        )
    }

    func requireSingleSession() throws {
        let documentCount = try runAppleScript(
            """
            tell application "TextEdit"
                return count of documents
            end tell
            """
        )
        guard documentCount == "1" else {
            throw HostSmokeError.preflightFailed(
                "Host smoke requires exactly one TextEdit document/session. Found \(documentCount). Close or restart TextEdit instead of opening multiple windows."
            )
        }
    }

    func typeText(_ text: String) throws {
        for character in text {
            guard let action = HostSmokeKeyboardMap.keyCodes[character.lowercased().first!] else {
                throw HostSmokeError.automationFailed(
                    "Unsupported smoke typing character: \(character)")
            }
            try press(action)
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    func press(_ action: HostSmokeKeyAction) throws {
        let modifierClause: String
        if action.modifiers.isEmpty {
            modifierClause = ""
        } else {
            modifierClause = " using {\(action.modifiers.joined(separator: ", "))}"
        }
        _ = try runAppleScript(
            """
            tell application "System Events"
                key code \(action.keyCode)\(modifierClause)
            end tell
            """
        )
    }

    func frontDocumentText() throws -> String {
        try runAppleScript(
            """
            tell application "TextEdit"
                return text of front document
            end tell
            """
        )
    }

    private func runAppleScript(_ source: String) throws -> String {
        let scriptURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("applescript")
        try source.write(to: scriptURL, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: scriptURL) }
        let result = try runner.run("/usr/bin/osascript", [scriptURL.path], allowFailure: false)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct HostSmokeScenarioArtifacts {
    let name: String
    let telemetryPath: String
    let mergedTelemetryPath: String
    let textPath: String?
}

private final class HostSmokeHarness {
    private let paths: BilineOperationPaths
    private let runner: any CommandRunning
    private let scenario: HostSmokeScenario
    private let fileManager: FileManager
    private let telemetryStore: BilineHostSmokeTelemetryStore
    private let textEdit: TextEditSmokeHost
    private let communicationHub: BilineCommunicationHub
    private let artifactsDirectory: URL
    private let startedAt: Date

    private var telemetryOffset: UInt64 = 0
    private var telemetryEvents: [BilineHostSmokeEvent] = []
    private var seenLogPayloads = Set<String>()
    private var lastLogRefreshAt: Date = .distantPast
    private var scenarioArtifacts: [HostSmokeScenarioArtifacts] = []
    private var scenarioStartedAt: Date

    init(
        paths: BilineOperationPaths,
        scenario: HostSmokeScenario,
        runner: any CommandRunning = ProcessCommandRunner(),
        fileManager: FileManager = .default
    ) {
        self.paths = paths
        self.scenario = scenario
        self.runner = runner
        self.fileManager = fileManager
        self.telemetryStore = BilineHostSmokeTelemetryStore(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle,
            homeDirectory: paths.homeDirectory,
            fileManager: fileManager
        )
        self.textEdit = TextEditSmokeHost(runner: runner, fileManager: fileManager)
        self.communicationHub = BilineCommunicationHub(
            inputMethodBundleIdentifier: BilineAppIdentifier.devInputMethodBundle
        )
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.startedAt = Date()
        self.scenarioStartedAt = startedAt
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        self.artifactsDirectory = paths.rootDirectory
            .appendingPathComponent("build/host-smoke-artifacts", isDirectory: true)
            .appendingPathComponent("\(scenario.rawValue)-\(timestamp)", isDirectory: true)
    }

    func run() throws -> String {
        try fileManager.createDirectory(at: artifactsDirectory, withIntermediateDirectories: true)
        let originalInputSource = InputSourceController.currentInputSourceID()
        let originalConfiguration = communicationHub.loadConfiguration()
        var configurationModified = false

        defer {
            if configurationModified {
                try? communicationHub.saveConfiguration(originalConfiguration)
            }
            if let originalInputSource, originalInputSource != BilineAppIdentifier.devInputSource {
                try? InputSourceController.select(inputSourceID: originalInputSource)
            }
        }

        do {
            try preflight()

            switch scenario {
            case .candidatePopup:
                try runCandidatePopupScenario()
            case .browse:
                try runBrowseScenario()
            case .commit:
                try runCommitScenario()
            case .settingsRefresh:
                configurationModified = true
                try runSettingsRefreshScenario(originalConfiguration: originalConfiguration)
            case .full:
                try runCandidatePopupScenario()
                try runBrowseScenario()
                try runCommitScenario()
                configurationModified = true
                try runSettingsRefreshScenario(originalConfiguration: originalConfiguration)
            }

            let diagnosticsURL = try writeDiagnostics()
            return """
                Host smoke passed.
                scenario=\(scenario.rawValue)
                artifacts=\(artifactsDirectory.path)
                diagnostics=\(diagnosticsURL.path)
                scenarios=\(scenarioArtifacts.map(\.name).joined(separator: ","))
                """
        } catch {
            let screenshotURL = captureScreenshot(name: "failure.png")
            let diagnosticsURL = try? writeDiagnostics()
            throw HostSmokeError.automationFailed(
                """
                Host smoke failed for scenario \(scenario.rawValue): \(error.localizedDescription)
                artifacts=\(artifactsDirectory.path)
                screenshot=\(screenshotURL?.path ?? "<unavailable>")
                diagnostics=\(diagnosticsURL?.path ?? "<unavailable>")
                """
            )
        }
    }

    private func preflight() throws {
        try require(
            AXIsProcessTrusted(),
            "Accessibility permission is required for host smoke automation. Grant access to the invoking terminal or IDE process in System Settings -> Privacy & Security -> Accessibility."
        )

        try textEdit.preflight()
        guard
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") != nil
        else {
            throw HostSmokeError.preflightFailed("TextEdit is not available on this system.")
        }

        let diagnostics = DevEnvironmentDiagnostics(
            paths: paths,
            runner: runner,
            fileManager: fileManager
        ).snapshot()
        try require(diagnostics.brokerInstalled, "BilineBrokerDev is not installed.")
        try require(diagnostics.brokerLaunchAgentInstalled, "Broker LaunchAgent is missing.")

        let readiness = diagnostics.inputSourceReadiness
        guard readiness.isReady else {
            throw HostSmokeError.preflightFailed(
                BilineCtl.formatReadinessFailure(readiness)
            )
        }
    }

    private func runCandidatePopupScenario() throws {
        try beginScenario(.candidatePopup)
        try textEdit.typeText("shi")
        _ = try waitForComposition(rawInput: "shi")
        _ = try waitForAnchorResolution()
        _ = try waitForEvent(
            description: "candidate panel to show"
        ) { event in
            event.kind == .panelShown
        }
        try persistScenarioArtifacts(named: HostSmokeScenario.candidatePopup.rawValue)
    }

    private func runBrowseScenario() throws {
        try beginScenario(.browse)
        try textEdit.typeText("shi")
        _ = try waitForComposition(rawInput: "shi")
        _ = try waitForAnchorResolution()
        _ = try waitForEvent(description: "candidate panel to show") { $0.kind == .panelShown }

        try textEdit.press(.browseDown)
        _ = try waitForEvent(description: "expanded row selection") { event in
            event.kind == .snapshot
                && event.fields["rawInput"] == "shi"
                && event.fields["presentationMode"] == "expanded"
                && event.fields["selectedRow"] == "1"
        }

        try textEdit.press(.moveRight)
        _ = try waitForEvent(description: "column move in expanded mode") { event in
            event.kind == .snapshot
                && event.fields["rawInput"] == "shi"
                && event.fields["presentationMode"] == "expanded"
                && event.fields["selectedColumn"] == "1"
        }
        try persistScenarioArtifacts(named: HostSmokeScenario.browse.rawValue)
    }

    private func runCommitScenario() throws {
        try beginScenario(.commit)
        try textEdit.typeText("shi")
        _ = try waitForComposition(rawInput: "shi")
        _ = try waitForAnchorResolution()
        _ = try waitForEvent(description: "candidate panel to show") { $0.kind == .panelShown }

        try textEdit.press(.selectCandidate1)
        let commitEvent = try waitForEvent(description: "candidate commit") { event in
            event.kind == .commit && event.fields["commitKind"] == "candidate"
        }
        let committedText = commitEvent.fields["committedText"] ?? ""
        try require(!committedText.isEmpty, "Committed text is empty.")
        let documentText = try waitForText(
            description: "TextEdit committed text",
            expected: committedText
        )
        try require(documentText == committedText, "TextEdit text did not match committed text.")
        try persistScenarioArtifacts(
            named: HostSmokeScenario.commit.rawValue,
            text: documentText
        )
    }

    private func runSettingsRefreshScenario(
        originalConfiguration: BilineSharedConfigurationSnapshot
    ) throws {
        try beginScenario(.settingsRefresh)
        try textEdit.typeText("shi")
        let initialSnapshot = try waitForComposition(rawInput: "shi")
        let originalCompactCount = originalConfiguration.settings.compactColumnCount
        let snapshotCompactCount =
            Int(initialSnapshot.fields["compactColumnCount"] ?? "") ?? originalCompactCount
        try require(
            snapshotCompactCount == originalCompactCount,
            "Initial compact column count did not match the current shared configuration."
        )

        var updatedConfiguration = originalConfiguration
        let nextCompactCount = originalCompactCount == 2 ? 3 : 2
        updatedConfiguration.settings.compactColumnCount = nextCompactCount
        try communicationHub.saveConfiguration(updatedConfiguration)

        _ = try waitForEvent(description: "settings refresh queued") { event in
            event.kind == .settingsRefreshQueued
                && event.fields["isComposing"] == "true"
        }

        Thread.sleep(forTimeInterval: 0.3)
        try require(
            !telemetryEvents.contains(where: {
                $0.kind == .snapshot
                    && $0.fields["rawInput"] == "shi"
                    && $0.fields["compactColumnCount"] == String(nextCompactCount)
            }),
            "Safe-boundary setting applied too early while composing."
        )

        try textEdit.press(.selectCandidate1)
        let commitEvent = try waitForEvent(description: "candidate commit for settings boundary") {
            event in
            event.kind == .commit && event.fields["commitKind"] == "candidate"
        }
        _ = try waitForEvent(description: "settings refresh applied after candidate commit") {
            event in
            event.kind == .settingsRefreshApplied
                && event.timestamp >= commitEvent.timestamp
        }

        try beginScenario(.settingsRefresh)
        try textEdit.typeText("shi")
        let refreshedSnapshot = try waitForComposition(rawInput: "shi")
        try require(
            refreshedSnapshot.fields["compactColumnCount"] == String(nextCompactCount),
            "Updated compact column count was not observed after the safe boundary."
        )
        try persistScenarioArtifacts(named: HostSmokeScenario.settingsRefresh.rawValue)
    }

    private func beginScenario(_ scenario: HostSmokeScenario) throws {
        telemetryOffset = 0
        telemetryEvents.removeAll()
        seenLogPayloads.removeAll()
        lastLogRefreshAt = .distantPast
        scenarioStartedAt = Date()
        try telemetryStore.reset()
        try textEdit.prepareBlankDocument()
        try selectTargetInputSource()
        try textEdit.focusTextArea()
        Thread.sleep(forTimeInterval: 0.35)
    }

    private func selectTargetInputSource() throws {
        let report = BilineInputSourceReadinessChecker().evaluate(bundleInstalled: true)
        guard report.isReady else {
            throw HostSmokeError.preflightFailed(BilineCtl.formatReadinessFailure(report))
        }
        if InputSourceController.currentInputSourceID() == BilineAppIdentifier.devInputSource {
            return
        }
        try InputSourceController.select(inputSourceID: BilineAppIdentifier.devInputSource)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if InputSourceController.currentInputSourceID() == BilineAppIdentifier.devInputSource {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw HostSmokeError.preflightFailed(
            "Failed to select \(BilineAppIdentifier.devInputSource). Current source is \(InputSourceController.currentInputSourceID() ?? "<missing>"). Try selecting it manually from the menu bar input picker, then re-run host smoke."
        )
    }

    private func waitForComposition(rawInput: String) throws -> BilineHostSmokeEvent {
        try waitForEvent(description: "composition snapshot for \(rawInput)") { event in
            event.kind == .snapshot
                && event.fields["rawInput"] == rawInput
                && event.fields["isComposing"] == "true"
                && (Int(event.fields["candidateCount"] ?? "0") ?? 0) > 0
        }
    }

    private func waitForAnchorResolution() throws -> BilineHostSmokeEvent {
        let deadline = Date().addingTimeInterval(5)
        var lastRejected: BilineHostSmokeEvent?
        while Date() < deadline {
            try refreshTelemetry()
            if let resolved = telemetryEvents.last(where: { $0.kind == .anchorResolved }) {
                return resolved
            }
            lastRejected =
                telemetryEvents.last(where: { $0.kind == .anchorRejected }) ?? lastRejected
            Thread.sleep(forTimeInterval: 0.1)
        }
        if let lastRejected {
            let details = [
                "source=\(lastRejected.fields["source"] ?? "unknown")",
                lastRejected.fields["queriedIndex"].map { "queriedIndex=\($0)" },
                lastRejected.fields["markedRangeLocation"].map {
                    "markedRange=\($0):\(lastRejected.fields["markedRangeLength"] ?? "unknown")"
                },
                lastRejected.fields["selectedRangeLocation"].map {
                    "selectedRange=\($0):\(lastRejected.fields["selectedRangeLength"] ?? "unknown")"
                },
                lastRejected.fields["actualRangeLocation"].map {
                    "actualRange=\($0):\(lastRejected.fields["actualRangeLength"] ?? "unknown")"
                },
            ].compactMap(\.self).joined(separator: " ")
            throw HostSmokeError.assertionFailed(
                "Anchor was rejected during host smoke: \(lastRejected.fields["reason"] ?? "unknown") \(details)."
            )
        }
        throw HostSmokeError.telemetryTimeout("Timed out waiting for anchor resolution.")
    }

    private func waitForEvent(
        timeout: TimeInterval = 6,
        description: String,
        predicate: (BilineHostSmokeEvent) -> Bool
    ) throws -> BilineHostSmokeEvent {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try refreshTelemetry()
            if let event = telemetryEvents.last(where: predicate) {
                return event
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw HostSmokeError.telemetryTimeout("Timed out waiting for \(description).")
    }

    private func waitForText(
        timeout: TimeInterval = 6,
        description: String,
        expected: String
    ) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let text = try textEdit.frontDocumentText()
            if text == expected {
                return text
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw HostSmokeError.telemetryTimeout("Timed out waiting for \(description).")
    }

    private func refreshTelemetry() throws {
        let result = try telemetryStore.loadNewEvents(afterByteOffset: telemetryOffset)
        telemetryOffset = result.nextOffset
        appendUnique(result.events)
        if Date().timeIntervalSince(lastLogRefreshAt) >= 1.0 {
            lastLogRefreshAt = Date()
            appendUnique(try loadLogEvents())
        }
    }

    private func loadLogEvents() throws -> [BilineHostSmokeEvent] {
        let result = try runner.run(
            "/usr/bin/log",
            [
                "show",
                "--last", "30s",
                "--predicate",
                "process == \"BilineIMEDev\" && eventMessage CONTAINS \"HOST_SMOKE_EVENT \"",
                "--style", "compact",
            ],
            allowFailure: false
        )
        guard !result.output.isEmpty else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var events: [BilineHostSmokeEvent] = []

        for line in result.output.split(separator: "\n") {
            guard let range = line.range(of: "HOST_SMOKE_EVENT ") else { continue }
            let payload = String(line[range.upperBound...])
            guard seenLogPayloads.insert(payload).inserted else { continue }
            guard let data = payload.data(using: .utf8),
                let event = try? decoder.decode(BilineHostSmokeEvent.self, from: data),
                event.timestamp >= scenarioStartedAt.addingTimeInterval(-1)
            else {
                continue
            }
            events.append(event)
        }

        return events
    }

    private func appendUnique(_ events: [BilineHostSmokeEvent]) {
        for event in events {
            let alreadySeen = telemetryEvents.contains {
                $0.timestamp == event.timestamp
                    && $0.kind == event.kind
                    && $0.fields == event.fields
            }
            if !alreadySeen {
                telemetryEvents.append(event)
            }
        }
    }

    @discardableResult
    private func persistScenarioArtifacts(
        named name: String,
        text: String? = nil
    ) throws -> HostSmokeScenarioArtifacts {
        let scenarioDirectory = artifactsDirectory.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: scenarioDirectory, withIntermediateDirectories: true)

        let telemetryURL = scenarioDirectory.appendingPathComponent(
            "telemetry.jsonl", isDirectory: false)
        if fileManager.fileExists(atPath: telemetryStore.fileURL.path) {
            try? fileManager.removeItem(at: telemetryURL)
            try fileManager.copyItem(at: telemetryStore.fileURL, to: telemetryURL)
        }
        let mergedTelemetryURL = scenarioDirectory.appendingPathComponent(
            "telemetry-merged.jsonl", isDirectory: false)
        try writeTelemetryEvents(telemetryEvents, to: mergedTelemetryURL)

        let textURL: URL?
        if let text {
            let url = scenarioDirectory.appendingPathComponent("text.txt", isDirectory: false)
            try text.write(to: url, atomically: true, encoding: .utf8)
            textURL = url
        } else {
            textURL = nil
        }

        let artifacts = HostSmokeScenarioArtifacts(
            name: name,
            telemetryPath: telemetryURL.path,
            mergedTelemetryPath: mergedTelemetryURL.path,
            textPath: textURL?.path
        )
        scenarioArtifacts.append(artifacts)
        return artifacts
    }

    private func writeTelemetryEvents(_ events: [BilineHostSmokeEvent], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try events.reduce(into: Data()) { partialResult, event in
            partialResult.append(try encoder.encode(event))
            partialResult.append(0x0A)
        }
        try data.write(to: url, options: [.atomic])
    }

    private func writeDiagnostics() throws -> URL {
        let diagnosticsURL = artifactsDirectory.appendingPathComponent(
            "diagnose.txt", isDirectory: false)
        let report = DevEnvironmentDiagnostics(
            paths: paths,
            runner: runner,
            fileManager: fileManager
        ).diagnosticReport()
        try report.write(to: diagnosticsURL, atomically: true, encoding: .utf8)
        return diagnosticsURL
    }

    private func captureScreenshot(name: String) -> URL? {
        let screenshotURL = artifactsDirectory.appendingPathComponent(name, isDirectory: false)
        do {
            _ = try runner.run(
                "/usr/sbin/screencapture",
                ["-x", screenshotURL.path],
                allowFailure: false
            )
            return screenshotURL
        } catch {
            return nil
        }
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw HostSmokeError.assertionFailed(message)
        }
    }
}

extension BilineCtl {
    static func smokeHost(arguments: [String]) throws -> String {
        guard arguments.count >= 2, arguments[0] == "smoke-host", arguments[1] == "dev" else {
            throw BilineOperationError.unsupportedArguments(usage)
        }

        let homeDirectory = try parseHomeDirectory(arguments)
        let paths = BilineOperationPaths(homeDirectory: homeDirectory)

        if arguments.contains("--check") {
            return checkInputSourceReadiness(paths: paths)
        }
        if arguments.contains("--prepare") {
            return prepareInputSourceReadiness(paths: paths)
        }

        guard arguments.contains("--confirm") else {
            throw BilineOperationError.confirmationRequiredForAction("smoke-host dev")
        }

        if arguments.contains("--install") {
            throw BilineOperationError.unsupportedArguments(
                """
                The --install flag has been removed from `smoke-host`.
                Install and source enrollment are separate phases now:
                  1. Run `bilinectl install dev --confirm` (or `make install-ime`).
                  2. Manually enable BilineIME Dev in System Settings → Keyboard → Input Sources.
                  3. Run `bilinectl smoke-host dev --check` (or `make smoke-ime-host-check`).
                  4. Run `bilinectl smoke-host dev --confirm` (or `make smoke-ime-host`).
                """
            )
        }

        let scenario = try parseHostSmokeScenario(arguments)
        return try HostSmokeHarness(paths: paths, scenario: scenario).run()
    }

    fileprivate static func parseHostSmokeScenario(_ arguments: [String]) throws
        -> HostSmokeScenario
    {
        guard let value = try value(forFlag: "--scenario", in: arguments) else {
            return .full
        }
        guard let scenario = HostSmokeScenario(rawValue: value) else {
            throw BilineOperationError.unsupportedArguments(
                "Missing or invalid --scenario candidate-popup|browse|commit|settings-refresh|full.\n\(usage)"
            )
        }
        return scenario
    }

    private static func checkInputSourceReadiness(paths: BilineOperationPaths) -> String {
        let snapshot = DevEnvironmentDiagnostics(paths: paths).snapshot()
        return renderReadinessReport(snapshot.inputSourceReadiness, header: "Input source readiness check")
    }

    private static func prepareInputSourceReadiness(paths: BilineOperationPaths) -> String {
        let initial = DevEnvironmentDiagnostics(paths: paths).snapshot().inputSourceReadiness
        if initial.isReady {
            return renderReadinessReport(
                initial,
                header: "Input source already ready; no manual onboarding required"
            )
        }

        var lines: [String] = []
        lines.append(renderReadinessReport(initial, header: "Input source readiness before assist"))
        lines.append("")

        if initial.state == .bundleMissing {
            lines.append(
                "Bundle missing: refusing to open System Settings because there is no input method to enable yet."
            )
            lines.append(
                "Run `make install-ime` (or `bilinectl install dev --confirm`) first, then re-run `bilinectl smoke-host dev --prepare`."
            )
            return lines.joined(separator: "\n")
        }

        let openedSettings = openInputSourcesSettings()
        if openedSettings {
            lines.append("Opened System Settings → Keyboard → Input Sources.")
        } else {
            lines.append(
                "Could not open System Settings automatically. Open it manually: System Settings → Keyboard → Input Sources."
            )
        }
        lines.append(
            "This helper does NOT click `Allow`, does NOT enable the source, and does NOT switch the active input source for you."
        )
        lines.append("Apple expects this onboarding step to be performed by the user once.")
        lines.append("")

        let recheck = DevEnvironmentDiagnostics(paths: paths).snapshot().inputSourceReadiness
        lines.append(
            renderReadinessReport(recheck, header: "Input source readiness after assist")
        )
        if !recheck.isReady {
            lines.append("")
            lines.append(
                "Source is still not ready. Finish the manual steps above, then re-run `bilinectl smoke-host dev --check` (or `make smoke-ime-host-check`)."
            )
        } else {
            lines.append("")
            lines.append(
                "Source is now ready. You can proceed with `bilinectl smoke-host dev --confirm` (or `make smoke-ime-host`)."
            )
        }
        return lines.joined(separator: "\n")
    }

    private static func openInputSourcesSettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?InputSources",
            "x-apple.systempreferences:com.apple.preference.keyboard?InputSources",
            "x-apple.systempreferences:com.apple.preference.keyboard",
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    static func formatReadinessFailure(_ report: BilineInputSourceReadinessReport) -> String {
        var lines: [String] = []
        lines.append(
            "Host smoke aborted: BilineIME input source is not ready (state=\(report.state.shortDescription))."
        )
        lines.append(report.summary)
        if !report.remediation.isEmpty {
            lines.append("Remediation:")
            for hint in report.remediation {
                lines.append("  - \(hint)")
            }
        }
        lines.append(
            "Re-evaluate with `bilinectl smoke-host dev --check`, or open System Settings → Keyboard → Input Sources via `bilinectl smoke-host dev --prepare`."
        )
        return lines.joined(separator: "\n")
    }

    private static func renderReadinessReport(
        _ report: BilineInputSourceReadinessReport,
        header: String
    ) -> String {
        var lines: [String] = [
            "== \(header) ==",
            "state=\(report.state.shortDescription)",
            "ready=\(report.isReady)",
            "input_source_id=\(report.inputSourceID)",
            "bundle_identifier=\(report.bundleIdentifier)",
            "bundle_installed=\(report.bundleInstalled)",
        ]
        if let snapshot = report.snapshot {
            lines.append(
                "source_localized_name=\(snapshot.localizedName.isEmpty ? "<empty>" : snapshot.localizedName)"
            )
            lines.append("source_enabled=\(snapshot.enabled)")
            lines.append("source_selectable=\(snapshot.selectable)")
            lines.append("source_selected=\(snapshot.selected)")
        } else {
            lines.append("source_registered=false")
        }
        lines.append("current_input_source=\(report.currentInputSourceID ?? "<unknown>")")
        lines.append("summary=\(report.summary)")
        if report.remediation.isEmpty {
            lines.append("remediation=none")
        } else {
            lines.append("remediation:")
            for hint in report.remediation {
                lines.append("  - \(hint)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
