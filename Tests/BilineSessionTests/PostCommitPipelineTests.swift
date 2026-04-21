import BilineCore
import BilineSession
import BilineTestSupport
import XCTest

final class PostCommitPipelineTests: XCTestCase {
    func testEmptyPipelineReturnsInputUnchanged() {
        let pipeline = PostCommitPipeline()
        let context = PostCommitContext(
            lastCommittedText: nil,
            lastCommitTimestamp: nil,
            hostBundleID: nil,
            punctuationForm: .fullwidth
        )

        XCTAssertEqual(pipeline.apply("hello", context: context), "hello")
        XCTAssertTrue(pipeline.isEmpty)
    }

    func testTransformsRunInOrder() {
        let pipeline = PostCommitPipeline([
            AppendTransform(suffix: "-A"),
            AppendTransform(suffix: "-B"),
        ])
        let context = PostCommitContext(
            lastCommittedText: nil,
            lastCommitTimestamp: nil,
            hostBundleID: nil,
            punctuationForm: .halfwidth
        )

        XCTAssertEqual(pipeline.apply("text", context: context), "text-A-B")
        XCTAssertFalse(pipeline.isEmpty)
    }

    func testSessionWithEmptyPipelinePreservesExistingCommitBehavior() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        // Default pipeline is empty so commits return the same text the
        // existing tests rely on.
        XCTAssertEqual(session.commitSelection(), "是")
    }

    func testSessionWithCustomPipelineRunsOnCommittedText() {
        let session = DemoFixtures.makeBilingualSession()
        session.postCommitPipeline = PostCommitPipeline([
            UppercaseAsciiTransform(),
            BracketTransform(),
        ])

        session.append(text: "shi")
        XCTAssertEqual(session.commitSelection(), "[是]")
    }

    func testPipelineSeesPreviousCommitOnSecondCommit() {
        let session = DemoFixtures.makeBilingualSession()
        let recorder = LastSeenRecorder()
        session.postCommitPipeline = PostCommitPipeline([recorder])

        session.append(text: "ni")
        _ = session.commitSelection()
        XCTAssertEqual(recorder.history.first?.previous, nil, "first commit has no previous")

        session.append(text: "shi")
        _ = session.commitSelection()
        XCTAssertEqual(recorder.history.last?.previous, "你",
            "second commit must see the first committed candidate")
    }

    func testCommitRawInputAlsoFlowsThroughPipeline() {
        let session = DemoFixtures.makeBilingualSession()
        session.postCommitPipeline = PostCommitPipeline([BracketTransform()])

        session.append(text: "ni")
        session.appendLiteral(text: "-")
        XCTAssertEqual(session.commitRawInput(), "[ni－]")
    }

    func testRenderCommittedTextRunsPipelineForExternallyInsertedText() {
        let session = DemoFixtures.makeBilingualSession()
        session.postCommitPipeline = PostCommitPipeline([BracketTransform()])

        XCTAssertEqual(session.renderCommittedText(","), "[，]")
    }

    func testCommitHistoryGrowsAndCapsAtLimit() {
        let session = DemoFixtures.makeBilingualSession()
        let recorder = HistoryRecorder()
        session.postCommitPipeline = PostCommitPipeline([recorder])

        // Drive a handful of commits through the session.
        for input in ["ni", "shi", "shi", "shi", "shi"] {
            session.append(text: input)
            _ = session.commitSelection()
        }

        // Each transform call records the history visible at that moment.
        // The very last call must see exactly `commitHistoryLimit` entries
        // (the oldest commits get rolled off) so memory stays bounded.
        let lastSeen = recorder.entries.last ?? []
        XCTAssertEqual(lastSeen.count, PostCommitContext.commitHistoryLimit)
    }
}

private final class HistoryRecorder: PostCommitTransform, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[String]] = []

    var entries: [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func transform(_ text: String, context: PostCommitContext) -> String {
        lock.lock()
        storage.append(context.commitHistory)
        lock.unlock()
        return text
    }
}

private struct AppendTransform: PostCommitTransform {
    let suffix: String
    func transform(_ text: String, context: PostCommitContext) -> String {
        text + suffix
    }
}

private struct UppercaseAsciiTransform: PostCommitTransform {
    func transform(_ text: String, context: PostCommitContext) -> String {
        text.uppercased()
    }
}

private struct BracketTransform: PostCommitTransform {
    func transform(_ text: String, context: PostCommitContext) -> String {
        "[\(text)]"
    }
}

private final class LastSeenRecorder: PostCommitTransform, @unchecked Sendable {
    struct Entry: Sendable, Equatable {
        let text: String
        let previous: String?
    }

    private let lock = NSLock()
    private var storage: [Entry] = []

    var history: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func transform(_ text: String, context: PostCommitContext) -> String {
        lock.lock()
        storage.append(Entry(text: text, previous: context.lastCommittedText))
        lock.unlock()
        return text
    }
}
