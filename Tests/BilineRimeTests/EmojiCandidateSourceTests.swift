import BilineCore
import BilineRime
import XCTest

final class EmojiCandidateSourceTests: XCTestCase {
    func testEmptySourceReturnsNoCandidates() {
        let source = EmptyEmojiCandidateSource()
        XCTAssertTrue(source.candidates(forPinyin: "ni").isEmpty)
        XCTAssertTrue(source.candidates(forPinyin: "").isEmpty)
        XCTAssertTrue(source.candidates(forPinyin: "haoxiao").isEmpty)
    }

    func testCustomSourceCanBeStubbedForFutureMerging() {
        // Demonstrates the protocol is usable for tests that want to inject
        // emoji into the candidate stream without booting librime.
        let source = StubEmojiSource(byInput: ["xiao": [
            Candidate(id: "emoji:smile", surface: "😄", reading: "xiao", score: 100)
        ]])
        XCTAssertEqual(source.candidates(forPinyin: "xiao").map(\.surface), ["😄"])
        XCTAssertTrue(source.candidates(forPinyin: "ni").isEmpty)
    }
}

private struct StubEmojiSource: EmojiCandidateSource {
    let byInput: [String: [Candidate]]

    func candidates(forPinyin rawInput: String) -> [Candidate] {
        byInput[rawInput] ?? []
    }
}
