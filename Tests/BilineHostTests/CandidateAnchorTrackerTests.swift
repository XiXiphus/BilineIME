import BilineHost
import XCTest

final class CandidateAnchorTrackerTests: XCTestCase {
    private let context = CandidateAnchorContext(clientID: "client-a", revision: 1)

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

    func testResolveDoesNotFallbackAcrossContexts() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)
        let nextRevision = CandidateAnchorContext(clientID: "client-a", revision: 2)
        let nextClient = CandidateAnchorContext(clientID: "client-b", revision: 1)

        XCTAssertEqual(tracker.resolve(currentRect: validRect, context: context), validRect)
        XCTAssertNil(tracker.resolve(currentRect: nil, context: nextRevision))
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
