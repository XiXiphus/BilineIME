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
    var annotationEnabled: Bool { get }
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

public actor PreviewCoordinator {
    private let provider: any TranslationProvider
    private let debounce: Duration
    private var cache: PreviewCache
    private var activeRequests: [UUID: ActivePreview]

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
        guard let candidate else {
            activeRequests.removeValue(forKey: sessionID)
            return .idle
        }

        let requestKey = makeRequestKey(for: candidate, targetLanguage: targetLanguage)
        let activePreview = ActivePreview(
            selectionRevision: selectionRevision,
            requestKey: requestKey
        )

        activeRequests[sessionID] = activePreview

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
        guard let candidate else {
            activeRequests.removeValue(forKey: sessionID)
            return .idle
        }

        let requestKey = makeRequestKey(for: candidate, targetLanguage: targetLanguage)
        let activePreview = ActivePreview(
            selectionRevision: selectionRevision,
            requestKey: requestKey
        )

        guard activeRequests[sessionID] == activePreview else {
            return .idle
        }

        if let cached = cache.value(for: requestKey) {
            activeRequests.removeValue(forKey: sessionID)
            return .ready(requestKey, cached)
        }

        if debounce > .zero {
            try? await Task.sleep(for: debounce)
            guard activeRequests[sessionID] == activePreview else {
                return .idle
            }
        }

        do {
            let preview = try await provider.translate(candidate.surface, target: targetLanguage)
            guard activeRequests[sessionID] == activePreview else {
                return .idle
            }
            cache.insert(preview, for: requestKey)
            activeRequests.removeValue(forKey: sessionID)
            return .ready(requestKey, preview)
        } catch {
            guard activeRequests[sessionID] == activePreview else {
                return .idle
            }
            activeRequests.removeValue(forKey: sessionID)
            return .failed(requestKey)
        }
    }

    public func cancel(sessionID: UUID) {
        activeRequests.removeValue(forKey: sessionID)
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
