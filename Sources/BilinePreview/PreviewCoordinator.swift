import BilineCore
import Foundation

public enum TargetLanguage: String, Sendable, Codable, CaseIterable {
    case english = "en"
}

public enum CharacterForm: String, Sendable, Codable, CaseIterable {
    case simplified
    case traditional
}

public protocol TranslationProvider: Sendable {
    var providerIdentifier: String { get }
    var providerModelIdentifier: String { get }
    var translationProfileIdentifier: String { get }
    func translate(_ text: String, target: TargetLanguage) async throws -> String
}

public extension TranslationProvider {
    var providerModelIdentifier: String { "default" }
    var translationProfileIdentifier: String { "default" }
}

public protocol BatchTranslationProvider: TranslationProvider {
    func translateBatch(_ texts: [String], target: TargetLanguage) async throws -> [String: String]
}

public protocol SettingsStore: Sendable {
    var targetLanguage: TargetLanguage { get }
    var previewEnabled: Bool { get }
    var compactColumnCount: Int { get }
    var expandedRowCount: Int { get }
    var fuzzyPinyinEnabled: Bool { get }
    var characterForm: CharacterForm { get }
    var pageSize: Int { get }
}

public struct PreviewRequestKey: Sendable, Equatable, Hashable {
    public let sourceText: String
    public let sourceLanguage: String
    public let targetLanguage: TargetLanguage
    public let providerIdentifier: String
    public let providerModelIdentifier: String
    public let translationProfileIdentifier: String

    public init(
        sourceText: String,
        sourceLanguage: String = "zh",
        targetLanguage: TargetLanguage,
        providerIdentifier: String,
        providerModelIdentifier: String = "default",
        translationProfileIdentifier: String = "default"
    ) {
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.providerIdentifier = providerIdentifier
        self.providerModelIdentifier = providerModelIdentifier
        self.translationProfileIdentifier = translationProfileIdentifier
    }
}

public enum PreviewRequestPriority: Int, Sendable, Comparable {
    case prefetch = 0
    case visible = 1
    case selected = 2

    public static func < (lhs: PreviewRequestPriority, rhs: PreviewRequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct TranslationPreviewSubscriberID: Sendable, Equatable, Hashable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
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
    private var recency: [PreviewRequestKey]
    private let capacity: Int

    public init(storage: [PreviewRequestKey: String] = [:], capacity: Int = 512) {
        self.storage = storage
        self.recency = Array(storage.keys)
        self.capacity = max(1, capacity)
        trimToCapacity()
    }

    public mutating func value(for key: PreviewRequestKey) -> String? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    public mutating func insert(_ value: String, for key: PreviewRequestKey) {
        storage[key] = value
        touch(key)
        trimToCapacity()
    }

    private mutating func touch(_ key: PreviewRequestKey) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    private mutating func trimToCapacity() {
        while storage.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}

public enum TranslationPreviewSchedulerError: Error, Equatable, Sendable {
    case timeout
    case cancelled
    case rateLimited
    case providerFailed
}

public actor TranslationPreviewScheduler {
    public struct Configuration: Sendable, Equatable {
        public let maxConcurrentRequests: Int
        public let maxRequestsPerSecond: Int
        public let requestTimeout: Duration
        public let rateLimitBackoff: Duration
        public let batchWindow: Duration
        public let maxBatchSize: Int

        public init(
            maxConcurrentRequests: Int = 2,
            maxRequestsPerSecond: Int = 3,
            requestTimeout: Duration = .milliseconds(1_200),
            rateLimitBackoff: Duration = .seconds(2),
            batchWindow: Duration = .milliseconds(50),
            maxBatchSize: Int = 8
        ) {
            self.maxConcurrentRequests = max(1, maxConcurrentRequests)
            self.maxRequestsPerSecond = max(1, maxRequestsPerSecond)
            self.requestTimeout = requestTimeout
            self.rateLimitBackoff = rateLimitBackoff
            self.batchWindow = batchWindow
            self.maxBatchSize = max(1, maxBatchSize)
        }
    }

    private struct ScheduledTranslation {
        let requestKey: PreviewRequestKey
        let text: String
        let target: TargetLanguage
        let sequence: Int
        var priority: PreviewRequestPriority
        var subscribers: [TranslationPreviewSubscriberID: CheckedContinuation<String, Error>]
        var isStarted: Bool = false
        var batchID: UUID?
    }

    private let provider: any TranslationProvider
    private let configuration: Configuration
    private var runningCount = 0
    private var requestStartDates: [Date] = []
    private var backoffUntil: Date?
    private var sequenceCounter = 0
    private var scheduledRequests: [PreviewRequestKey: ScheduledTranslation] = [:]
    private var flushTask: Task<Void, Never>?
    private var runningBatchTasks: [UUID: Task<Void, Never>] = [:]
    private var keysByBatch: [UUID: Set<PreviewRequestKey>] = [:]

    public init(
        provider: any TranslationProvider,
        configuration: Configuration = Configuration()
    ) {
        self.provider = provider
        self.configuration = configuration
    }

    public func translate(
        _ text: String,
        target: TargetLanguage,
        requestKey: PreviewRequestKey,
        priority: PreviewRequestPriority = .selected,
        subscriberID: TranslationPreviewSubscriberID? = nil
    ) async throws -> String {
        let resolvedSubscriberID = subscriberID ?? TranslationPreviewSubscriberID(UUID().uuidString)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueue(
                    text: text,
                    target: target,
                    requestKey: requestKey,
                    priority: priority,
                    subscriberID: resolvedSubscriberID,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { [resolvedSubscriberID] in
                await self.cancel(requestKey, subscriberID: resolvedSubscriberID)
            }
        }
    }

    public func cancel(_ requestKey: PreviewRequestKey) {
        guard let request = scheduledRequests.removeValue(forKey: requestKey) else { return }
        for continuation in request.subscribers.values {
            continuation.resume(throwing: TranslationPreviewSchedulerError.cancelled)
        }
        cancelBatchIfUnused(afterRemoving: request)
    }

    public func cancel(
        _ requestKey: PreviewRequestKey,
        subscriberID: TranslationPreviewSubscriberID
    ) {
        guard var request = scheduledRequests[requestKey] else { return }
        guard let continuation = request.subscribers.removeValue(forKey: subscriberID) else {
            return
        }

        continuation.resume(throwing: TranslationPreviewSchedulerError.cancelled)

        if request.subscribers.isEmpty {
            scheduledRequests.removeValue(forKey: requestKey)
            cancelBatchIfUnused(afterRemoving: request)
        } else {
            scheduledRequests[requestKey] = request
        }
    }

    private func enqueue(
        text: String,
        target: TargetLanguage,
        requestKey: PreviewRequestKey,
        priority: PreviewRequestPriority,
        subscriberID: TranslationPreviewSubscriberID,
        continuation: CheckedContinuation<String, Error>
    ) {
        if var request = scheduledRequests[requestKey] {
            if let previous = request.subscribers.updateValue(continuation, forKey: subscriberID) {
                previous.resume(throwing: TranslationPreviewSchedulerError.cancelled)
            }
            request.priority = max(request.priority, priority)
            scheduledRequests[requestKey] = request
            return
        }

        sequenceCounter += 1
        scheduledRequests[requestKey] = ScheduledTranslation(
            requestKey: requestKey,
            text: text,
            target: target,
            sequence: sequenceCounter,
            priority: priority,
            subscribers: [subscriberID: continuation]
        )
        scheduleFlush(after: configuration.batchWindow)
    }

    private func scheduleFlush(after delay: Duration) {
        guard flushTask == nil else { return }
        flushTask = Task { [delay] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            self.flushPendingBatch()
        }
    }

    private func flushPendingBatch() {
        flushTask = nil

        let queued = scheduledRequests.values
            .filter { !$0.isStarted && !$0.subscribers.isEmpty }
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }
                return $0.sequence < $1.sequence
            }

        guard let first = queued.first else { return }

        let selected = queued
            .filter { $0.target == first.target }
            .prefix(configuration.maxBatchSize)

        let batchID = UUID()
        let requestKeys = selected.map(\.requestKey)
        let requestKeySet = Set(requestKeys)

        for requestKey in requestKeys {
            guard var request = scheduledRequests[requestKey] else { continue }
            request.isStarted = true
            request.batchID = batchID
            scheduledRequests[requestKey] = request
        }

        keysByBatch[batchID] = requestKeySet
        runningBatchTasks[batchID] = Task { [requestKeys] in
            await self.runBatch(batchID: batchID, requestKeys: requestKeys)
        }

        if scheduledRequests.values.contains(where: { !$0.isStarted && !$0.subscribers.isEmpty }) {
            scheduleFlush(after: .zero)
        }
    }

    private func runBatch(batchID: UUID, requestKeys: [PreviewRequestKey]) async {
        defer { cleanupBatch(batchID) }

        let requests = requestKeys.compactMap { scheduledRequests[$0] }
        guard !requests.isEmpty else { return }

        if let batchProvider = provider as? any BatchTranslationProvider, requests.count > 1 {
            await runProviderBatch(batchProvider, requests: requests)
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for requestKey in requestKeys {
                group.addTask {
                    await self.runSingle(requestKey: requestKey)
                }
            }
        }
    }

    private func runProviderBatch(
        _ batchProvider: any BatchTranslationProvider,
        requests: [ScheduledTranslation]
    ) async {
        let texts = requests.map(\.text)
        let target = requests[0].target

        do {
            let results = try await executeProviderCall {
                try await batchProvider.translateBatch(texts, target: target)
            }

            for request in requests {
                if let translated = results[request.text] {
                    complete(request.requestKey, result: .success(translated))
                } else {
                    complete(
                        request.requestKey,
                        result: .failure(TranslationPreviewSchedulerError.providerFailed)
                    )
                }
            }
        } catch {
            for request in requests {
                complete(request.requestKey, result: .failure(error))
            }
        }
    }

    private func runSingle(requestKey: PreviewRequestKey) async {
        guard let request = scheduledRequests[requestKey], !request.subscribers.isEmpty else {
            return
        }

        do {
            let translated = try await executeProviderCall { [provider] in
                try await provider.translate(request.text, target: request.target)
            }
            complete(requestKey, result: .success(translated))
        } catch {
            complete(requestKey, result: .failure(error))
        }
    }

    private func executeProviderCall<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await waitForRequestSlot(configuration: configuration)
        defer {
            finishRequest()
        }

        do {
            return try await Self.withTimeout(configuration.requestTimeout, operation: operation)
        } catch let error as TranslationPreviewSchedulerError {
            if error == .rateLimited {
                startBackoff(configuration.rateLimitBackoff)
            }
            throw error
        } catch is CancellationError {
            throw TranslationPreviewSchedulerError.cancelled
        } catch {
            throw TranslationPreviewSchedulerError.providerFailed
        }
    }

    private func complete(_ requestKey: PreviewRequestKey, result: Result<String, Error>) {
        guard let request = scheduledRequests.removeValue(forKey: requestKey) else { return }

        for continuation in request.subscribers.values {
            switch result {
            case .success(let value):
                continuation.resume(returning: value)
            case .failure(let error):
                continuation.resume(throwing: normalizedError(error))
            }
        }
    }

    private func normalizedError(_ error: Error) -> TranslationPreviewSchedulerError {
        if let schedulerError = error as? TranslationPreviewSchedulerError {
            return schedulerError
        }
        if error is CancellationError {
            return .cancelled
        }
        return .providerFailed
    }

    private func cancelBatchIfUnused(afterRemoving request: ScheduledTranslation) {
        guard let batchID = request.batchID else { return }
        let batchKeys = keysByBatch[batchID] ?? []
        let hasSubscribers = batchKeys.contains { requestKey in
            guard let request = scheduledRequests[requestKey] else { return false }
            return !request.subscribers.isEmpty
        }
        if !hasSubscribers {
            runningBatchTasks[batchID]?.cancel()
        }
    }

    private func cleanupBatch(_ batchID: UUID) {
        for requestKey in keysByBatch[batchID] ?? [] {
            if var request = scheduledRequests[requestKey], request.batchID == batchID {
                request.batchID = nil
                scheduledRequests[requestKey] = request
            }
        }
        keysByBatch.removeValue(forKey: batchID)
        runningBatchTasks.removeValue(forKey: batchID)
    }

    private func waitForRequestSlot(configuration: Configuration) async throws {
        while true {
            try Task.checkCancellation()

            let now = Date()
            requestStartDates = requestStartDates.filter { now.timeIntervalSince($0) < 1.0 }

            let isBackingOff = backoffUntil.map { now < $0 } ?? false
            if !isBackingOff,
                runningCount < configuration.maxConcurrentRequests,
                requestStartDates.count < configuration.maxRequestsPerSecond
            {
                runningCount += 1
                requestStartDates.append(now)
                return
            }

            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func finishRequest() {
        runningCount = max(0, runningCount - 1)
    }

    private func startBackoff(_ duration: Duration) {
        backoffUntil = Date().addingTimeInterval(duration.secondsApproximation)
    }

    private static func withTimeout<T: Sendable>(
        _ timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw TranslationPreviewSchedulerError.timeout
            }

            guard let result = try await group.next() else {
                throw TranslationPreviewSchedulerError.providerFailed
            }
            group.cancelAll()
            return result
        }
    }
}

private extension Duration {
    var secondsApproximation: TimeInterval {
        let components = components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
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
        schedulerConfiguration: TranslationPreviewScheduler.Configuration = TranslationPreviewScheduler.Configuration()
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
        let cancelledRequests = activeRequests
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

private extension ActivePreviewID {
    var schedulerSubscriberID: TranslationPreviewSubscriberID {
        TranslationPreviewSubscriberID("\(sessionID.uuidString):\(requestID)")
    }
}
