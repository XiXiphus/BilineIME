import BilineHost
import XCTest

final class CandidateAnchorTrackerTests: XCTestCase {
    private let context = CandidateAnchorContext(clientID: "client-a")

    func testResolveReturnsCurrentRectWhenValid() {
        let tracker = CandidateAnchorTracker()
        let rect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: rect, context: context), rect)
    }

    func testResolveFallsBackToLastValidRectForSameContext() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)
        let invalidRect = CandidateAnchorRect(x: .nan, y: 20, width: 0, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: validRect, context: context), validRect)
        XCTAssertEqual(tracker.resolve(currentRect: invalidRect, context: context), validRect)
        XCTAssertEqual(tracker.resolve(currentRect: nil, context: context), validRect)
    }

    func testResolveReusesLastValidRectAcrossKeystrokesForSameClient() {
        // The cache is keyed by clientID so that a momentary invalid rect
        // from the host (common during marked-text reflows) does not jump
        // the candidate panel back to (0, 0). Successive keystrokes against
        // the same client must continue to see the last good rect.
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: validRect, context: context), validRect)
        XCTAssertEqual(tracker.resolve(currentRect: nil, context: context), validRect)
    }

    func testResolveDoesNotFallbackAcrossClients() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)
        let nextClient = CandidateAnchorContext(clientID: "client-b")

        XCTAssertEqual(tracker.resolve(currentRect: validRect, context: context), validRect)
        XCTAssertNil(tracker.resolve(currentRect: nil, context: nextClient))
    }

    func testResolveReturnsNilWhenNoValidRectExistsYet() {
        let tracker = CandidateAnchorTracker()
        let invalidRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 0)

        XCTAssertNil(tracker.resolve(currentRect: invalidRect, context: context))
        XCTAssertNil(tracker.resolve(currentRect: nil, context: context))
    }

    func testClearDropsLastValidRect() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 1, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: validRect, context: context), validRect)
        tracker.clear()
        XCTAssertNil(tracker.resolve(currentRect: nil, context: context))
    }
}
