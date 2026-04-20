import BilineCore
import BilinePreview
import XCTest

final class TranslationPreviewSchedulerTests: XCTestCase {
    func testConcurrentRequestsAreLimited() async throws {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(60))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 2,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50)
            )
        )

        try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<25 {
                let text = "候选\(index)"
                let key = PreviewRequestKey(
                    sourceText: text,
                    targetLanguage: .english,
                    providerIdentifier: provider.providerIdentifier
                )
                group.addTask {
                    try await scheduler.translate(text, target: .english, requestKey: key)
                }
            }

            for try await _ in group {}
        }

        let stats = await provider.stats()
        XCTAssertLessThanOrEqual(stats.maxActive, 2)
        XCTAssertEqual(stats.callCount, 25)
    }

    func testDuplicateRequestsAreCoalesced() async throws {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(40))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 2,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50)
            )
        )
        let key = PreviewRequestKey(
            sourceText: "你好",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )

        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await scheduler.translate("你好", target: .english, requestKey: key)
                }
            }

            for try await value in group {
                XCTAssertEqual(value, "[en] 你好")
            }
        }

        let stats = await provider.stats()
        XCTAssertEqual(stats.callCount, 1)
    }

    func testBatchProviderCoalescesVisibleRequestsInFlushWindow() async throws {
        let provider = BatchInstrumentedTranslationProvider(delay: .milliseconds(20))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 2,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50),
                batchWindow: .milliseconds(80),
                maxBatchSize: 8
            )
        )

        try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0..<3 {
                let text = "候选\(index)"
                let key = PreviewRequestKey(
                    sourceText: text,
                    targetLanguage: .english,
                    providerIdentifier: provider.providerIdentifier
                )
                group.addTask {
                    try await scheduler.translate(
                        text,
                        target: .english,
                        requestKey: key,
                        priority: .visible
                    )
                }
            }

            for try await _ in group {}
        }

        let stats = await provider.stats()
        XCTAssertEqual(stats.singleCallCount, 0)
        XCTAssertEqual(stats.batches.count, 1)
        XCTAssertEqual(Set(stats.batches[0]), Set(["候选0", "候选1", "候选2"]))
    }

    func testSelectedPriorityStartsBeforeVisibleRequests() async throws {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(30))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 1,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50),
                batchWindow: .milliseconds(60),
                maxBatchSize: 1
            )
        )
        let visibleKey = PreviewRequestKey(
            sourceText: "普通",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let selectedKey = PreviewRequestKey(
            sourceText: "选中",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )

        let visible = Task {
            try await scheduler.translate(
                "普通",
                target: .english,
                requestKey: visibleKey,
                priority: .visible
            )
        }
        try await Task.sleep(for: .milliseconds(10))
        let selected = Task {
            try await scheduler.translate(
                "选中",
                target: .english,
                requestKey: selectedKey,
                priority: .selected
            )
        }

        _ = try await visible.value
        _ = try await selected.value

        let stats = await provider.stats()
        XCTAssertEqual(stats.startedTexts.first, "选中")
    }

    func testCancellingOneSubscriberDoesNotCancelSharedProviderJob() async throws {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(20))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 1,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50),
                batchWindow: .milliseconds(60)
            )
        )
        let key = PreviewRequestKey(
            sourceText: "你好",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let firstID = TranslationPreviewSubscriberID("first")
        let secondID = TranslationPreviewSubscriberID("second")

        let first = Task {
            try await scheduler.translate(
                "你好",
                target: .english,
                requestKey: key,
                subscriberID: firstID
            )
        }
        try await Task.sleep(for: .milliseconds(10))
        let second = Task {
            try await scheduler.translate(
                "你好",
                target: .english,
                requestKey: key,
                subscriberID: secondID
            )
        }
        try await Task.sleep(for: .milliseconds(10))
        await scheduler.cancel(key, subscriberID: firstID)

        do {
            _ = try await first.value
            XCTFail("Expected first subscriber to be cancelled.")
        } catch TranslationPreviewSchedulerError.cancelled {
        } catch {
            XCTFail("Expected cancelled, got \(error).")
        }

        let secondValue = try await second.value
        XCTAssertEqual(secondValue, "[en] 你好")

        let stats = await provider.stats()
        XCTAssertEqual(stats.callCount, 1)
    }

    func testRequestRateIsLimited() async throws {
        let provider = InstrumentedTranslationProvider(delay: .zero)
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 5,
                maxRequestsPerSecond: 1,
                requestTimeout: .seconds(3),
                rateLimitBackoff: .milliseconds(50)
            )
        )
        let firstKey = PreviewRequestKey(
            sourceText: "一",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let secondKey = PreviewRequestKey(
            sourceText: "二",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let start = ContinuousClock.now

        async let first = scheduler.translate("一", target: .english, requestKey: firstKey)
        async let second = scheduler.translate("二", target: .english, requestKey: secondKey)
        _ = try await [first, second]

        let elapsed = start.duration(to: .now)
        XCTAssertGreaterThanOrEqual(elapsed.secondsApproximation, 0.9)
    }

    func testPendingRequestCanBeCancelledBeforeProviderStarts() async throws {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(120))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 1,
                maxRequestsPerSecond: 100,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50)
            )
        )
        let firstKey = PreviewRequestKey(
            sourceText: "一",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let secondKey = PreviewRequestKey(
            sourceText: "二",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )

        let first = Task {
            try await scheduler.translate("一", target: .english, requestKey: firstKey)
        }
        try await Task.sleep(for: .milliseconds(20))
        let second = Task {
            try await scheduler.translate("二", target: .english, requestKey: secondKey)
        }
        try await Task.sleep(for: .milliseconds(20))
        await scheduler.cancel(secondKey)

        _ = try await first.value
        do {
            _ = try await second.value
            XCTFail("Expected pending request to be cancelled.")
        } catch TranslationPreviewSchedulerError.cancelled {
        } catch {
            XCTFail("Expected cancelled, got \(error).")
        }

        let stats = await provider.stats()
        XCTAssertEqual(stats.startedTexts, ["一"])
    }

    func testTimeoutReturnsSchedulerFailure() async {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(200))
        let scheduler = TranslationPreviewScheduler(
            provider: provider,
            configuration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 1,
                maxRequestsPerSecond: 100,
                requestTimeout: .milliseconds(20),
                rateLimitBackoff: .milliseconds(50)
            )
        )
        let key = PreviewRequestKey(
            sourceText: "慢",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )

        do {
            _ = try await scheduler.translate("慢", target: .english, requestKey: key)
            XCTFail("Expected timeout.")
        } catch TranslationPreviewSchedulerError.timeout {
        } catch {
            XCTFail("Expected timeout, got \(error).")
        }
    }

    func testCoordinatorCacheHitDoesNotUseSchedulerCapacity() async {
        let provider = InstrumentedTranslationProvider(delay: .milliseconds(20))
        let key = PreviewRequestKey(
            sourceText: "你好",
            targetLanguage: .english,
            providerIdentifier: provider.providerIdentifier
        )
        let coordinator = PreviewCoordinator(
            provider: provider,
            cache: PreviewCache(storage: [key: "hello"], capacity: 512),
            debounce: .zero,
            schedulerConfiguration: TranslationPreviewScheduler.Configuration(
                maxConcurrentRequests: 1,
                maxRequestsPerSecond: 1,
                requestTimeout: .seconds(2),
                rateLimitBackoff: .milliseconds(50)
            )
        )
        let candidate = Candidate(id: "nihao", surface: "你好", reading: "ni hao", score: 1)

        let started = await coordinator.startPreview(
            sessionID: UUID(),
            selectionRevision: 1,
            candidate: candidate,
            targetLanguage: .english
        )

        XCTAssertEqual(started, .ready(key, "hello"))
        let stats = await provider.stats()
        XCTAssertEqual(stats.callCount, 0)
    }
}

private actor InstrumentedTranslationProvider: TranslationProvider {
    nonisolated let providerIdentifier = "instrumented"

    private let delay: Duration
    private var activeCount = 0
    private var maxActiveCount = 0
    private var translatedTexts: [String] = []

    init(delay: Duration) {
        self.delay = delay
    }

    func translate(_ text: String, target: TargetLanguage) async throws -> String {
        activeCount += 1
        maxActiveCount = max(maxActiveCount, activeCount)
        translatedTexts.append(text)
        defer { activeCount -= 1 }

        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return "[\(target.rawValue)] \(text)"
    }

    func stats() -> (callCount: Int, maxActive: Int, startedTexts: [String]) {
        (translatedTexts.count, maxActiveCount, translatedTexts)
    }
}

private actor BatchInstrumentedTranslationProvider: BatchTranslationProvider {
    nonisolated let providerIdentifier = "batch.instrumented"

    private let delay: Duration
    private var activeBatchCount = 0
    private var maxActiveBatchCount = 0
    private var batchTexts: [[String]] = []
    private var singleTexts: [String] = []

    init(delay: Duration) {
        self.delay = delay
    }

    func translate(_ text: String, target: TargetLanguage) async throws -> String {
        singleTexts.append(text)
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return "[\(target.rawValue)] \(text)"
    }

    func translateBatch(_ texts: [String], target: TargetLanguage) async throws -> [String: String] {
        activeBatchCount += 1
        maxActiveBatchCount = max(maxActiveBatchCount, activeBatchCount)
        batchTexts.append(texts)
        defer { activeBatchCount -= 1 }

        if delay > .zero {
            try await Task.sleep(for: delay)
        }

        return Dictionary(uniqueKeysWithValues: texts.map { ($0, "[\(target.rawValue)] \($0)") })
    }

    func stats() -> (batches: [[String]], singleCallCount: Int, maxActiveBatches: Int) {
        (batchTexts, singleTexts.count, maxActiveBatchCount)
    }
}

private extension Duration {
    var secondsApproximation: TimeInterval {
        let components = components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
