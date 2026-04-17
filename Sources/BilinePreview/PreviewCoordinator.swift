import BilineCore
import Foundation

public enum TargetLanguage: String, Sendable, Codable, CaseIterable {
    case english = "en"
}

public protocol TranslationProvider: Sendable {
    var providerIdentifier: String { get }
    func translate(_ text: String, target: TargetLanguage) async throws -> String
}

public protocol SettingsStore: Sendable {
    var targetLanguage: TargetLanguage { get }
    var previewEnabled: Bool { get }
    var compactColumnCount: Int { get }
    var expandedRowCount: Int { get }
    var pageSize: Int { get }
}

public struct PreviewRequestKey: Sendable, Equatable, Hashable {
    public let sourceText: String
    public let targetLanguage: TargetLanguage
    public let providerIdentifier: String

    public init(sourceText: String, targetLanguage: TargetLanguage, providerIdentifier: String) {
        self.sourceText = sourceText
        self.targetLanguage = targetLanguage
        self.providerIdentifier = providerIdentifier
    }
}

public enum PreviewState: Sendable, Equatable {
    case idle
    case loading(PreviewRequestKey, Int)
    case ready(PreviewRequestKey, String)
    case failed(PreviewRequestKey)
}

public struct PreviewCache: Sendable {
    private var storage: [PreviewRequestKey: String]

    public init(storage: [PreviewRequestKey: String] = [:]) {
        self.storage = storage
    }

    public func value(for key: PreviewRequestKey) -> String? {
        storage[key]
    }

    public mutating func insert(_ value: String, for key: PreviewRequestKey) {
        storage[key] = value
    }
}

private struct ActivePreview: Sendable, Equatable {
    let selectionRevision: Int
    let requestKey: PreviewRequestKey
}

private struct ActivePreviewID: Sendable, Equatable, Hashable {
    let sessionID: UUID
    let requestID: String
}

public actor PreviewCoordinator {
    private let provider: any TranslationProvider
    private let debounce: Duration
    private var cache: PreviewCache
    private var activeRequests: [ActivePreviewID: ActivePreview]

    public init(
        provider: any TranslationProvider,
        cache: PreviewCache = PreviewCache(),
        debounce: Duration = .milliseconds(120)
    ) {
        self.provider = provider
        self.cache = cache
        self.debounce = debounce
        self.activeRequests = [:]
    }

    public func startPreview(
        sessionID: UUID,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage
    ) -> PreviewState {
        startPreview(
            sessionID: sessionID,
            requestID: "__selected__",
            selectionRevision: selectionRevision,
            candidate: candidate,
            targetLanguage: targetLanguage
        )
    }

    public func startPreview(
        sessionID: UUID,
        requestID: String,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage
    ) -> PreviewState {
        let activePreviewID = ActivePreviewID(sessionID: sessionID, requestID: requestID)
        guard let candidate else {
            activeRequests.removeValue(forKey: activePreviewID)
            return .idle
        }

        let requestKey = makeRequestKey(for: candidate, targetLanguage: targetLanguage)
        let activePreview = ActivePreview(
            selectionRevision: selectionRevision,
            requestKey: requestKey
        )

        activeRequests[activePreviewID] = activePreview

        if let cached = cache.value(for: requestKey) {
            return .ready(requestKey, cached)
        }

        return .loading(requestKey, selectionRevision)
    }

    public func resolvePreview(
        sessionID: UUID,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage
    ) async -> PreviewState {
        await resolvePreview(
            sessionID: sessionID,
            requestID: "__selected__",
            selectionRevision: selectionRevision,
            candidate: candidate,
            targetLanguage: targetLanguage
        )
    }

    public func resolvePreview(
        sessionID: UUID,
        requestID: String,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage
    ) async -> PreviewState {
        let activePreviewID = ActivePreviewID(sessionID: sessionID, requestID: requestID)
        guard let candidate else {
            activeRequests.removeValue(forKey: activePreviewID)
            return .idle
        }

        let requestKey = makeRequestKey(for: candidate, targetLanguage: targetLanguage)
        let activePreview = ActivePreview(
            selectionRevision: selectionRevision,
            requestKey: requestKey
        )

        guard activeRequests[activePreviewID] == activePreview else {
            return .idle
        }

        if let cached = cache.value(for: requestKey) {
            activeRequests.removeValue(forKey: activePreviewID)
            return .ready(requestKey, cached)
        }

        if debounce > .zero {
            try? await Task.sleep(for: debounce)
            guard activeRequests[activePreviewID] == activePreview else {
                return .idle
            }
        }

        do {
            let preview = try await provider.translate(candidate.surface, target: targetLanguage)
            guard activeRequests[activePreviewID] == activePreview else {
                return .idle
            }
            cache.insert(preview, for: requestKey)
            activeRequests.removeValue(forKey: activePreviewID)
            return .ready(requestKey, preview)
        } catch {
            guard activeRequests[activePreviewID] == activePreview else {
                return .idle
            }
            activeRequests.removeValue(forKey: activePreviewID)
            return .failed(requestKey)
        }
    }

    public func cancel(sessionID: UUID) {
        activeRequests = activeRequests.filter { $0.key.sessionID != sessionID }
    }

    public func cancel(sessionID: UUID, requestID: String) {
        activeRequests.removeValue(
            forKey: ActivePreviewID(sessionID: sessionID, requestID: requestID)
        )
    }

    private func makeRequestKey(
        for candidate: Candidate,
        targetLanguage: TargetLanguage
    ) -> PreviewRequestKey {
        PreviewRequestKey(
            sourceText: candidate.surface,
            targetLanguage: targetLanguage,
            providerIdentifier: provider.providerIdentifier
        )
    }
}
