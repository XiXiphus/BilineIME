import BilineCore
import Foundation

private struct ActivePreview: Sendable, Equatable {
    let selectionRevision: Int
    let requestKey: PreviewRequestKey
}

private struct ActivePreviewID: Sendable, Equatable, Hashable {
    let sessionID: UUID
    let requestID: String
}

public actor PreviewCoordinator {
    private let providerIdentifier: String
    private let providerModelIdentifier: String
    private let translationProfileIdentifier: String
    private let scheduler: TranslationPreviewScheduler
    private let debounce: Duration
    private var cache: PreviewCache
    private var activeRequests: [ActivePreviewID: ActivePreview]

    public init(
        provider: any TranslationProvider,
        cache: PreviewCache = PreviewCache(),
        debounce: Duration = .milliseconds(120),
        schedulerConfiguration: TranslationPreviewScheduler.Configuration =
            TranslationPreviewScheduler.Configuration()
    ) {
        self.providerIdentifier = provider.providerIdentifier
        self.providerModelIdentifier = provider.providerModelIdentifier
        self.translationProfileIdentifier = provider.translationProfileIdentifier
        self.scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: schedulerConfiguration
        )
        self.cache = cache
        self.debounce = debounce
        self.activeRequests = [:]
    }

    public func startPreview(
        sessionID: UUID,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage,
        priority: PreviewRequestPriority = .selected
    ) -> PreviewState {
        startPreview(
            sessionID: sessionID,
            requestID: "__selected__",
            selectionRevision: selectionRevision,
            candidate: candidate,
            targetLanguage: targetLanguage,
            priority: priority
        )
    }

    public func startPreview(
        sessionID: UUID,
        requestID: String,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage,
        priority: PreviewRequestPriority = .selected
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
            activeRequests.removeValue(forKey: activePreviewID)
            return .ready(requestKey, cached)
        }

        return .loading(requestKey, selectionRevision)
    }

    public func resolvePreview(
        sessionID: UUID,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage,
        priority: PreviewRequestPriority = .selected
    ) async -> PreviewState {
        await resolvePreview(
            sessionID: sessionID,
            requestID: "__selected__",
            selectionRevision: selectionRevision,
            candidate: candidate,
            targetLanguage: targetLanguage,
            priority: priority
        )
    }

    public func resolvePreview(
        sessionID: UUID,
        requestID: String,
        selectionRevision: Int,
        candidate: Candidate?,
        targetLanguage: TargetLanguage,
        priority: PreviewRequestPriority = .selected
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
            let preview = try await scheduler.translate(
                candidate.surface,
                target: targetLanguage,
                requestKey: requestKey,
                priority: priority,
                subscriberID: activePreviewID.schedulerSubscriberID
            )
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

    public func cancel(sessionID: UUID) async {
        let cancelledRequests =
            activeRequests
            .filter { $0.key.sessionID == sessionID }
            .map { (activePreviewID: $0.key, requestKey: $0.value.requestKey) }
        activeRequests = activeRequests.filter { $0.key.sessionID != sessionID }
        for request in cancelledRequests {
            await scheduler.cancel(
                request.requestKey,
                subscriberID: request.activePreviewID.schedulerSubscriberID
            )
        }
    }

    public func cancel(sessionID: UUID, requestID: String) async {
        let removed = activeRequests.removeValue(
            forKey: ActivePreviewID(sessionID: sessionID, requestID: requestID)
        )
        if let removed {
            await scheduler.cancel(
                removed.requestKey,
                subscriberID: ActivePreviewID(
                    sessionID: sessionID,
                    requestID: requestID
                ).schedulerSubscriberID
            )
        }
    }

    private func makeRequestKey(
        for candidate: Candidate,
        targetLanguage: TargetLanguage
    ) -> PreviewRequestKey {
        PreviewRequestKey(
            sourceText: candidate.surface,
            targetLanguage: targetLanguage,
            providerIdentifier: providerIdentifier,
            providerModelIdentifier: providerModelIdentifier,
            translationProfileIdentifier: translationProfileIdentifier
        )
    }
}

extension ActivePreviewID {
    fileprivate var schedulerSubscriberID: TranslationPreviewSubscriberID {
        TranslationPreviewSubscriberID("\(sessionID.uuidString):\(requestID)")
    }
}
