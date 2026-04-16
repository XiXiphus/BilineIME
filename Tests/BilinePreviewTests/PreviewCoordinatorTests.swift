import BilineCore
import BilinePreview
import BilineTestSupport
import Foundation
import XCTest

final class PreviewCoordinatorTests: XCTestCase {
    func testCachedPreviewReturnsReadyImmediately() async {
        let coordinator = DemoFixtures.makeCoordinator()
        let candidate = Candidate(id: "nihao", surface: "你好", reading: "ni hao", score: 1500)
        let sessionID = UUID()

        let initial = await coordinator.startPreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: candidate,
            targetLanguage: .english
        )

        XCTAssertEqual(
            initial,
            .loading(
                PreviewRequestKey(
                    sourceText: "你好",
                    targetLanguage: .english,
                    providerIdentifier: "mock.fixture"
                ),
                1
            )
        )

        let resolved = await coordinator.resolvePreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: candidate,
            targetLanguage: .english
        )

        XCTAssertEqual(
            resolved,
            .ready(
                PreviewRequestKey(
                    sourceText: "你好",
                    targetLanguage: .english,
                    providerIdentifier: "mock.fixture"
                ),
                "hello"
            )
        )

        let cached = await coordinator.startPreview(
            sessionID: sessionID,
            selectionRevision: 2,
            candidate: candidate,
            targetLanguage: .english
        )

        XCTAssertEqual(
            cached,
            .ready(
                PreviewRequestKey(
                    sourceText: "你好",
                    targetLanguage: .english,
                    providerIdentifier: "mock.fixture"
                ),
                "hello"
            )
        )
    }

    func testStaleResultIsDroppedWhenNewerSelectionStarts() async {
        let coordinator = DemoFixtures.makeCoordinator(delay: .milliseconds(60))
        let sessionID = UUID()
        let oldCandidate = Candidate(id: "nihao", surface: "你好", reading: "ni hao", score: 1500)
        let newCandidate = Candidate(
            id: "zhongguo", surface: "中国", reading: "zhong guo", score: 1500)

        _ = await coordinator.startPreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: oldCandidate,
            targetLanguage: .english
        )

        async let stale = coordinator.resolvePreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: oldCandidate,
            targetLanguage: .english
        )

        _ = await coordinator.startPreview(
            sessionID: sessionID,
            selectionRevision: 2,
            candidate: newCandidate,
            targetLanguage: .english
        )

        let staleResult = await stale
        let freshResult = await coordinator.resolvePreview(
            sessionID: sessionID,
            selectionRevision: 2,
            candidate: newCandidate,
            targetLanguage: .english
        )

        XCTAssertEqual(staleResult, .idle)
        XCTAssertEqual(
            freshResult,
            .ready(
                PreviewRequestKey(
                    sourceText: "中国",
                    targetLanguage: .english,
                    providerIdentifier: "mock.fixture"
                ),
                "China"
            )
        )
    }

    func testFailureReturnsFailedState() async {
        let coordinator = DemoFixtures.makeCoordinator(failures: ["你好"])
        let sessionID = UUID()
        let candidate = Candidate(id: "nihao", surface: "你好", reading: "ni hao", score: 1500)

        _ = await coordinator.startPreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: candidate,
            targetLanguage: .english
        )

        let resolved = await coordinator.resolvePreview(
            sessionID: sessionID,
            selectionRevision: 1,
            candidate: candidate,
            targetLanguage: .english
        )

        XCTAssertEqual(
            resolved,
            .failed(
                PreviewRequestKey(
                    sourceText: "你好",
                    targetLanguage: .english,
                    providerIdentifier: "mock.fixture"
                )
            )
        )
    }
}
