import BilineCore
import BilineSession
import BilineTestSupport
import XCTest

final class PreferredDefaultLayerTests: XCTestCase {
    func testDefaultPreferredLayerKeepsExistingChineseFirstBehavior() {
        let session = DemoFixtures.makeBilingualSession()

        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
    }

    func testNewCompositionStartsInPreferredEnglishLayerWhenSet() {
        let session = DemoFixtures.makeBilingualSession()
        session.preferredDefaultLayer = .english

        // First composition: cancel + restart picks up the new default.
        session.cancel()
        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testCommitResetsToPreferredLayerForNextComposition() {
        let session = DemoFixtures.makeBilingualSession()
        session.preferredDefaultLayer = .english

        session.cancel()
        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
        _ = session.commitChineseSelection()
        // After a clean reset, the next composition should still default
        // to English because the per-app preference has not changed.
        session.append(text: "ma")
        XCTAssertEqual(session.snapshot.activeLayer, .english)
    }

    func testFlippingPreferredLayerBackToChineseTakesEffectOnNextComposition() {
        let session = DemoFixtures.makeBilingualSession()
        session.preferredDefaultLayer = .english
        session.cancel()
        session.append(text: "shi")
        XCTAssertEqual(session.snapshot.activeLayer, .english)

        // User refocuses a non-overridden app. Controller switches the
        // preference back to .chinese, then cancels the active composition
        // (existing switchActiveClient behavior). Next composition starts
        // in Chinese.
        session.preferredDefaultLayer = .chinese
        session.cancel()
        session.append(text: "ma")
        XCTAssertEqual(session.snapshot.activeLayer, .chinese)
    }
}
