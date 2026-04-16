import BilineSession
import BilineTestSupport
import XCTest

final class BilingualInputSessionTests: XCTestCase {
    func testShiftToggleChangesLayerWithoutChangingSelection() {
        let session = DemoFixtures.makeBilingualSession(pageSize: 5)

        session.append(text: "nihao")
        let before = session.snapshot

        session.toggleActiveLayer()
        let after = session.snapshot

        XCTAssertEqual(before.selectedIndex, after.selectedIndex)
        XCTAssertEqual(after.activeLayer, .english)
    }

    func testMovingSelectionKeepsEnglishLayerActive() async {
        let session = DemoFixtures.makeBilingualSession(pageSize: 5)

        session.append(text: "shi")
        session.toggleActiveLayer()
        session.moveSelection(.next)

        XCTAssertEqual(session.snapshot.activeLayer, .english)
        XCTAssertEqual(session.snapshot.selectedIndex, 1)
    }

    func testEnglishCommitUsesReadyPreviewText() async {
        let session = DemoFixtures.makeBilingualSession(pageSize: 5)
        let ready = expectation(description: "english preview ready")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.activeLayer == .english,
                snapshot.selectedIndex == 0,
                snapshot.items.first?.englishText == "hello"
            else {
                return
            }
            didFulfill = true
            ready.fulfill()
        }

        session.append(text: "nihao")
        session.toggleActiveLayer()

        await fulfillment(of: [ready], timeout: 1.0)

        XCTAssertEqual(session.commitSelection(), "hello")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
        XCTAssertEqual(session.snapshot, .idle)
    }

    func testEnglishCommitStaysBlockedWhilePreviewIsLoading() {
        let session = DemoFixtures.makeBilingualSession(pageSize: 5, delay: .milliseconds(60))

        session.append(text: "nihao")
        session.toggleActiveLayer()

        XCTAssertNil(session.commitSelection())
        XCTAssertTrue(session.snapshot.isComposing)
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testSwitchingPagesLoadsVisibleCandidatesWithoutCorruptingNewPage() async {
        let session = DemoFixtures.makeBilingualSession(pageSize: 2, delay: .milliseconds(40))
        let pageTwo = expectation(description: "page two english preview ready")
        var didFulfill = false

        session.onSnapshotUpdate = { snapshot in
            guard !didFulfill else { return }
            guard snapshot.pageIndex == 1,
                snapshot.items.first?.candidate.surface == "事",
                snapshot.items.first?.englishText == "matter"
            else {
                return
            }
            didFulfill = true
            pageTwo.fulfill()
        }

        session.append(text: "shi")
        session.turnPage(.next)

        await fulfillment(of: [pageTwo], timeout: 1.0)

        XCTAssertEqual(session.snapshot.pageIndex, 1)
        XCTAssertEqual(session.snapshot.items.map(\.candidate.surface), ["事", "市"])
        XCTAssertEqual(session.snapshot.items.first?.englishText, "matter")
        session.cancel()
    }
}
