import BilineHost
import XCTest

final class CandidateAnchorTrackerTests: XCTestCase {
    func testResolveReturnsCurrentRectWhenValid() {
        let tracker = CandidateAnchorTracker()
        let rect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: rect), rect)
    }

    func testResolveFallsBackToLastValidRect() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 18)
        let invalidRect = CandidateAnchorRect(x: .nan, y: 20, width: 0, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: validRect), validRect)
        XCTAssertEqual(tracker.resolve(currentRect: invalidRect), validRect)
        XCTAssertEqual(tracker.resolve(currentRect: nil), validRect)
    }

    func testResolveReturnsNilWhenNoValidRectExistsYet() {
        let tracker = CandidateAnchorTracker()
        let invalidRect = CandidateAnchorRect(x: 10, y: 20, width: 0, height: 0)

        XCTAssertNil(tracker.resolve(currentRect: invalidRect))
        XCTAssertNil(tracker.resolve(currentRect: nil))
    }

    func testClearDropsLastValidRect() {
        let tracker = CandidateAnchorTracker()
        let validRect = CandidateAnchorRect(x: 10, y: 20, width: 1, height: 18)

        XCTAssertEqual(tracker.resolve(currentRect: validRect), validRect)
        tracker.clear()
        XCTAssertNil(tracker.resolve(currentRect: nil))
    }
}
