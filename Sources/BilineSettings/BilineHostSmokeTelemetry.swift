import Foundation

public enum BilineHostSmokeEventKind: String, Codable, CaseIterable, Sendable {
    case appLaunch
    case inputControllerInitialized
    case activeClientChanged
    case snapshot
    case renderSkippedNoActiveClient
    case settingsRefreshQueued
    case settingsRefreshApplied
    case anchorResolved
    case anchorRejected
    case panelRenderRequested
    case panelShown
    case panelUpdated
    case panelHidden
    case markedTextApplied
    case compositionCleared
    case commit
}

public struct BilineHostSmokeEvent: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let bundleIdentifier: String
    public let processIdentifier: Int32
    public let kind: BilineHostSmokeEventKind
    public let fields: [String: String]

    public init(
        timestamp: Date = Date(),
        bundleIdentifier: String,
        processIdentifier: Int32 = Int32(ProcessInfo.processInfo.processIdentifier),
        kind: BilineHostSmokeEventKind,
        fields: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.kind = kind
        self.fields = fields
    }
}

public final class BilineHostSmokeTelemetryStore: @unchecked Sendable {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(
        inputMethodBundleIdentifier: String = BilineAppIdentifier.devInputMethodBundle,
        fileURL: URL? = nil,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.fileURL =
            fileURL
            ?? BilineAppPath.hostSmokeTelemetryFileURL(
                inputMethodBundleIdentifier: inputMethodBundleIdentifier,
                homeDirectory: homeDirectory
            )
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func reset() throws {
        lock.lock()
        defer { lock.unlock() }
        try? fileManager.removeItem(at: fileURL)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: fileURL, options: [.atomic])
    }

    public func append(_ event: BilineHostSmokeEvent) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !fileManager.fileExists(atPath: fileURL.path) {
                try Data().write(to: fileURL, options: [.atomic])
            }
            let data = try encoder.encode(event) + Data([0x0A])
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Smoke telemetry is debug-only evidence collection; it must never
            // interfere with the IME hot path.
        }
    }

    public func load() throws -> [BilineHostSmokeEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return [] }
        return try decodeLines(data)
    }

    public func loadNewEvents(afterByteOffset offset: UInt64) throws -> (events: [BilineHostSmokeEvent], nextOffset: UInt64) {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ([], offset)
        }
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        guard fileSize > offset else {
            return ([], fileSize)
        }
        try handle.seek(toOffset: offset)
        let data = try handle.readToEnd() ?? Data()
        guard !data.isEmpty else {
            return ([], fileSize)
        }
        return (try decodeLines(data), fileSize)
    }

    private func decodeLines(_ data: Data) throws -> [BilineHostSmokeEvent] {
        let lines = data.split(separator: 0x0A)
        return try lines.compactMap { line in
            guard !line.isEmpty else { return nil }
            return try decoder.decode(BilineHostSmokeEvent.self, from: Data(line))
        }
    }
}
