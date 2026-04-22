import AppKit
import ApplicationServices
import BilineIPC
import BilineOperations
import BilineSettings
import Darwin
import Foundation

private struct HostSmokeScenarioArtifacts {
    let name: String
    let telemetryPath: String
    let mergedTelemetryPath: String
    let textPath: String?
}

final class HostSmokeHarness {
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
        // #region agent log
        AgentDebugLogger.write(
            hypothesisId: "H2",
            location: "Sources/bilinectl/HostSmokeHarness.swift:runCandidatePopupScenario",
            message: "typed candidate-popup seed text",
            data: [
                "scenario": HostSmokeScenario.candidatePopup.rawValue,
                "currentInputSource": InputSourceController.currentInputSourceID() ?? "<missing>",
                "frontDocumentText": (try? textEdit.frontDocumentText()) ?? "<error>",
                "textAreaFocused": (try? textEdit.isTextAreaFocused()) ?? "<error>",
            ]
        )
        // #endregion
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
        _ = try waitForEvent(description: "candidate commit for settings boundary") {
            event in
            event.kind == .commit && event.fields["commitKind"] == "candidate"
        }
        _ = try waitForEvent(description: "settings refresh applied at safe boundary") {
            event in
            event.kind == .settingsRefreshApplied
                && event.fields["changed"] == "true"
                && event.fields["compactColumnCountAfterRefresh"] == String(nextCompactCount)
        }

        try prepareScenario(.settingsRefresh, restartTextEdit: false)
        try textEdit.typeText("shi")
        let refreshedSnapshot = try waitForComposition(rawInput: "shi")
        try require(
            refreshedSnapshot.fields["compactColumnCount"] == String(nextCompactCount),
            "Updated compact column count was not observed after the safe boundary."
        )
        try persistScenarioArtifacts(named: HostSmokeScenario.settingsRefresh.rawValue)
    }

    private func beginScenario(_ scenario: HostSmokeScenario) throws {
        try prepareScenario(scenario, restartTextEdit: true)
    }

    private func prepareScenario(
        _ scenario: HostSmokeScenario,
        restartTextEdit: Bool
    ) throws {
        telemetryOffset = 0
        telemetryEvents.removeAll()
        seenLogPayloads.removeAll()
        lastLogRefreshAt = .distantPast
        scenarioStartedAt = Date()
        try telemetryStore.reset()
        if restartTextEdit {
            try textEdit.prepareBlankDocument()
        } else {
            try textEdit.resetFrontDocument()
        }
        try selectTargetInputSource()
        try textEdit.focusTextArea()
        // #region agent log
        AgentDebugLogger.write(
            hypothesisId: "H5",
            location: "Sources/bilinectl/HostSmokeHarness.swift:prepareScenario",
            message: "prepared TextEdit before scenario typing",
            data: [
                "restartTextEdit": String(restartTextEdit),
                "scenario": scenario.rawValue,
                "documentCount": (try? textEdit.documentCount()) ?? "<error>",
                "textAreaFocused": (try? textEdit.isTextAreaFocused()) ?? "<error>",
                "currentInputSource": InputSourceController.currentInputSourceID() ?? "<missing>",
                "frontDocumentText": (try? textEdit.frontDocumentText()) ?? "<error>",
            ]
        )
        // #endregion
        Thread.sleep(forTimeInterval: 0.35)
    }

    private func selectTargetInputSource() throws {
        let report = BilineInputSourceReadinessChecker().evaluate(bundleInstalled: true)
        guard report.isReady else {
            throw HostSmokeError.preflightFailed(BilineCtl.formatReadinessFailure(report))
        }
        if InputSourceController.currentInputSourceID() == BilineAppIdentifier.devInputSource {
            // #region agent log
            AgentDebugLogger.write(
                hypothesisId: "H1",
                location: "Sources/bilinectl/HostSmokeHarness.swift:selectTargetInputSource",
                message: "input source already set before smoke selection",
                data: [
                    "readinessState": report.state.shortDescription,
                    "currentInputSource": InputSourceController.currentInputSourceID() ?? "<missing>",
                ]
            )
            // #endregion
            return
        }
        let previousInputSource = InputSourceController.currentInputSourceID() ?? "<missing>"
        try InputSourceController.select(inputSourceID: BilineAppIdentifier.devInputSource)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if InputSourceController.currentInputSourceID() == BilineAppIdentifier.devInputSource {
                // #region agent log
                AgentDebugLogger.write(
                    hypothesisId: "H1",
                    location: "Sources/bilinectl/HostSmokeHarness.swift:selectTargetInputSource",
                    message: "selected BilineIME input source for smoke",
                    data: [
                        "readinessState": report.state.shortDescription,
                        "beforeInputSource": previousInputSource,
                        "afterInputSource": InputSourceController.currentInputSourceID() ?? "<missing>",
                    ]
                )
                // #endregion
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
        // #region agent log
        AgentDebugLogger.write(
            hypothesisId: "H4",
            location: "Sources/bilinectl/HostSmokeHarness.swift:waitForEvent",
            message: "timed out waiting for host smoke event",
            data: [
                "description": description,
                "telemetryCount": String(telemetryEvents.count),
                "lastTelemetryKinds": telemetryEvents.suffix(5).map(\.kind.rawValue).joined(separator: ","),
                "lastTelemetryRawInput": telemetryEvents.last?.fields["rawInput"] ?? "<none>",
                "currentInputSource": InputSourceController.currentInputSourceID() ?? "<missing>",
            ]
        )
        // #endregion
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
        let output = try runLogShowFallback(timeout: 1.5)
        guard !output.isEmpty else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var events: [BilineHostSmokeEvent] = []

        for line in output.split(separator: "\n") {
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

    private func runLogShowFallback(timeout: TimeInterval) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--last", "30s",
            "--predicate",
            "process == \"BilineIMEDev\" && eventMessage CONTAINS \"HOST_SMOKE_EVENT \"",
            "--style", "compact",
        ]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        if process.isRunning {
            process.terminate()
            let terminateDeadline = Date().addingTimeInterval(0.2)
            while process.isRunning, Date() < terminateDeadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            }
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            // #region agent log
            AgentDebugLogger.write(
                hypothesisId: "H4",
                location: "Sources/bilinectl/HostSmokeHarness.swift:runLogShowFallback",
                message: "log show fallback timed out",
                data: [
                    "timeoutSeconds": String(timeout),
                    "scenario": scenario.rawValue,
                ]
            )
            // #endregion
            return ""
        }

        let output =
            String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            ?? ""
        let errorOutput =
            String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            ?? ""
        if process.terminationStatus != 0 {
            // The file-backed telemetry path is the source of truth; this log
            // query is only a non-fatal fallback.
            return ""
        }
        if !errorOutput.isEmpty {
            // Ignore stderr-only noise from `log show`.
        }
        return output
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
