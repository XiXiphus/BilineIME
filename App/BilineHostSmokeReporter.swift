#if DEBUG
    import OSLog
    import BilineSettings
    import Foundation

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
        }
    }
#endif
