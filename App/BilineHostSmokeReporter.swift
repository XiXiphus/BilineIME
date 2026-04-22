#if DEBUG
    import OSLog
    import BilineSettings
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
                // Debug logging must never break smoke telemetry.
            }
        }
    }

    final class BilineHostSmokeReporter: @unchecked Sendable {
        static let shared = BilineHostSmokeReporter()
        private static let eventEncoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return encoder
        }()

        private let store: BilineHostSmokeTelemetryStore
        private let bundleIdentifier: String
        private let logger: Logger

        private init() {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? BilineAppIdentifier.devInputMethodBundle
            self.bundleIdentifier = bundleIdentifier
            self.logger = Logger(subsystem: bundleIdentifier, category: "host-smoke")
            let cachesDirectory =
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? BilineAppPath.hostSmokeTelemetryFileURL(
                    inputMethodBundleIdentifier: bundleIdentifier
                ).deletingLastPathComponent()
            let fileURL = cachesDirectory
                .appendingPathComponent("BilineIME/Smoke", isDirectory: true)
                .appendingPathComponent("telemetry.jsonl", isDirectory: false)
            self.store = BilineHostSmokeTelemetryStore(
                inputMethodBundleIdentifier: bundleIdentifier,
                fileURL: fileURL
            )
        }

        func record(_ kind: BilineHostSmokeEventKind, fields: [String: String?] = [:]) {
            let compactFields = fields.reduce(into: [String: String]()) { partialResult, entry in
                if let value = entry.value {
                    partialResult[entry.key] = value
                }
            }
            let event = BilineHostSmokeEvent(
                bundleIdentifier: bundleIdentifier,
                kind: kind,
                fields: compactFields
            )
            store.append(event)
            if let data = try? Self.eventEncoder.encode(event),
                let payload = String(data: data, encoding: .utf8)
            {
                logger.notice("HOST_SMOKE_EVENT \(payload, privacy: .public)")
            }
            // #region agent log
            AgentDebugLogger.write(
                hypothesisId: "H4",
                location: "App/BilineHostSmokeReporter.swift:82",
                message: "recorded host smoke telemetry event",
                data: [
                    "kind": kind.rawValue,
                    "rawInput": compactFields["rawInput"] ?? "<none>",
                    "isComposing": compactFields["isComposing"] ?? "<none>",
                    "candidateCount": compactFields["candidateCount"] ?? "<none>",
                ]
            )
            // #endregion
        }
    }
#endif
