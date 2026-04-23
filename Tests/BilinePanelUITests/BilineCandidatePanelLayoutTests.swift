import BilineCore
@testable import BilinePanelUI
import BilineSession
import Cocoa
import XCTest

@MainActor
final class BilineCandidatePanelLayoutTests: XCTestCase {
    func testCompactChineseOnlyUsesSingleRoundedStrip() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: false,
            presentationMode: .compact,
            selectedRow: 0,
            selectedColumn: 0
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))

        XCTAssertNil(rects.english)
        XCTAssertEqual(rects.chinese.height, view.stripHeight(rowCount: 1), accuracy: 0.001)
        XCTAssertEqual(
            view.preferredSize.height,
            ceil(view.contentInsets.top + view.stripHeight(rowCount: 1) + view.contentInsets.bottom),
            accuracy: 0.001
        )
    }

    func testBilingualCompactUsesTwoMatchingSingleRowStrips() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .compact,
            selectedRow: 0,
            selectedColumn: 1
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let englishRect = try XCTUnwrap(rects.english)

        XCTAssertEqual(rects.chinese.height, view.stripHeight(rowCount: 1), accuracy: 0.001)
        XCTAssertEqual(englishRect.height, rects.chinese.height, accuracy: 0.001)
        XCTAssertEqual(englishRect.minY, rects.chinese.maxY + view.blockSpacing, accuracy: 0.001)
        XCTAssertEqual(englishRect.width, rects.chinese.width, accuracy: 0.001)
    }

    func testExpandedStripHeightTracksVisibleRows() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .expanded,
            selectedRow: 2,
            selectedColumn: 1,
            compactColumnCount: 4,
            expandedRowCount: 3
        )

        XCTAssertEqual(view.snapshot.visibleRowCount, 3)

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let englishRect = try XCTUnwrap(rects.english)

        XCTAssertEqual(rects.chinese.height, view.stripHeight(rowCount: 3), accuracy: 0.001)
        XCTAssertEqual(englishRect.height, rects.chinese.height, accuracy: 0.001)
        XCTAssertGreaterThan(rects.chinese.height, view.stripHeight(rowCount: 1))
    }

    func testSelectedExpandedTokenStaysInsideSelectedRow() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .expanded,
            selectedRow: 2,
            selectedColumn: 1,
            compactColumnCount: 4,
            expandedRowCount: 3
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let selectedTokenRect = try XCTUnwrap(
            view.candidateTokenRect(
                layer: .chinese,
                row: 2,
                column: 1,
                in: rects.chinese,
                columnWidths: columnWidths
            )
        )
        let selectedRowRect = view.rowRect(in: rects.chinese, row: 2)

        XCTAssertGreaterThanOrEqual(selectedTokenRect.minY, selectedRowRect.minY)
        XCTAssertLessThanOrEqual(selectedTokenRect.maxY, selectedRowRect.maxY)
    }

    func testFirstCandidateStartsAtStripLeadingEdge() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .compact,
            selectedRow: 0,
            selectedColumn: 0
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let firstTokenRect = try XCTUnwrap(
            view.candidateTokenRect(
                layer: .chinese,
                row: 0,
                column: 0,
                in: rects.chinese,
                columnWidths: columnWidths
            )
        )

        XCTAssertEqual(firstTokenRect.minX, rects.chinese.minX, accuracy: 0.001)
    }

    func testSelectedTokenUsesStripVerticalEdges() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .compact,
            selectedRow: 0,
            selectedColumn: 0
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let firstTokenRect = try XCTUnwrap(
            view.candidateTokenRect(
                layer: .chinese,
                row: 0,
                column: 0,
                in: rects.chinese,
                columnWidths: columnWidths
            )
        )

        XCTAssertEqual(firstTokenRect.minY, rects.chinese.minY, accuracy: 0.001)
        XCTAssertEqual(firstTokenRect.maxY, rects.chinese.maxY, accuracy: 0.001)
    }

    func testChineseAndEnglishLayersShareColumnOrigins() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        view.snapshot = makeSnapshot(
            showsEnglishCandidates: true,
            presentationMode: .expanded,
            selectedRow: 1,
            selectedColumn: 2,
            compactColumnCount: 4,
            expandedRowCount: 3
        )

        let columnWidths = view.columnWidths()
        let rects = try XCTUnwrap(view.stripRects(columnWidths: columnWidths))
        let englishRect = try XCTUnwrap(rects.english)
        let chineseTokenRect = try XCTUnwrap(
            view.candidateTokenRect(
                layer: .chinese,
                row: 1,
                column: 2,
                in: rects.chinese,
                columnWidths: columnWidths
            )
        )
        let englishTokenRect = try XCTUnwrap(
            view.candidateTokenRect(
                layer: .english,
                row: 1,
                column: 2,
                in: englishRect,
                columnWidths: columnWidths
            )
        )

        XCTAssertEqual(chineseTokenRect.minX, englishTokenRect.minX, accuracy: 0.001)
    }

    func testCandidateNumberPrefixUsesCenteredBaselineOffset() throws {
        let view = BilineCandidatePanelView(frame: .zero)
        let firstItem = try XCTUnwrap(candidateItems.first)

        let line = view.candidateLine(column: 0, item: firstItem, selected: false, active: false)
        let baselineOffset = try XCTUnwrap(
            line.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat
        )

        XCTAssertGreaterThan(baselineOffset, 0)
        XCTAssertEqual(
            baselineOffset,
            view.numberBaselineOffset(for: view.chineseFont),
            accuracy: 0.001
        )
    }

    private func makeSnapshot(
        showsEnglishCandidates: Bool,
        presentationMode: CandidatePresentationMode,
        selectedRow: Int,
        selectedColumn: Int,
        compactColumnCount: Int = 5,
        expandedRowCount: Int = 5
    ) -> BilingualCompositionSnapshot {
        BilingualCompositionSnapshot(
            rawInput: "nihao",
            remainingRawInput: "",
            displayRawInput: "nihao",
            markedText: "nihao",
            rawCursorIndex: 5,
            markedSelectionLocation: 5,
            items: candidateItems,
            showsEnglishCandidates: showsEnglishCandidates,
            pageIndex: 0,
            activeLayer: .chinese,
            presentationMode: presentationMode,
            selectedRow: selectedRow,
            selectedColumn: selectedColumn,
            compactColumnCount: compactColumnCount,
            expandedRowCount: expandedRowCount,
            isComposing: true
        )
    }

    private var candidateItems: [BilingualCandidateItem] {
        [
            item(id: "nihao", surface: "你好", english: "Hello"),
            item(id: "buhao", surface: "不好", english: "Not good"),
            item(id: "nihaoma", surface: "你好吗", english: "How are you?"),
            item(id: "nihao-number", surface: "你号", english: "Your number"),
            item(id: "ni", surface: "你", english: "You"),
            item(id: "niha", surface: "你哈", english: "Hi"),
            item(id: "ni-wave", surface: "👋", english: "Wave"),
            item(id: "ni-alt", surface: "尼", english: "Ni"),
            item(id: "hao", surface: "号", english: "Number"),
            item(id: "hao-alt", surface: "好", english: "Good"),
        ]
    }

    private func item(id: String, surface: String, english: String) -> BilingualCandidateItem {
        BilingualCandidateItem(
            candidate: Candidate(
                id: id,
                surface: surface,
                reading: "nihao",
                score: 100,
                consumedTokenCount: 2
            ),
            previewState: .ready(english)
        )
    }
}
