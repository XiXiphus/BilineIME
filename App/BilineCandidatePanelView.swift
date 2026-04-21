import BilineSession
import Cocoa

final class BilineCandidatePanelView: NSView {
    var snapshot: BilingualCompositionSnapshot = .idle {
        didSet {
            if oldValue.rawInput != snapshot.rawInput
                || oldValue.items.map(\.candidate.id) != snapshot.items.map(\.candidate.id)
            {
                lineSizeCache.removeAll()
            }
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }

    override var isFlipped: Bool { true }

    let contentInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    let blockSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 4
    let columnSpacing: CGFloat = 6
    let rowInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    let segmentPadding = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
    let minimumColumnWidth: CGFloat = 28
    let segmentBreathingRoom: CGFloat = 2
    let chineseFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
    let englishFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    let fallbackFontResolver = SystemFallbackFontResolver()
    private var lineSizeCache: [CandidatePanelLineSizeKey: NSSize] = [:]

    override var intrinsicContentSize: NSSize {
        preferredSize
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSnapshot()
    }

    func candidateLineSize(column: Int, item: BilingualCandidateItem) -> NSSize {
        cachedLineSize(
            kind: "candidate",
            column: column,
            item: item,
            previewKey: ""
        ) {
            candidateLine(column: column, item: item, active: false).size()
        }
    }

    func englishLineSize(column: Int, item: BilingualCandidateItem) -> NSSize {
        cachedLineSize(
            kind: "english",
            column: column,
            item: item,
            previewKey: item.previewState.cacheKey
        ) {
            englishLine(column: column, item: item, active: false).size()
        }
    }

    private func cachedLineSize(
        kind: String,
        column: Int,
        item: BilingualCandidateItem,
        previewKey: String,
        measure: () -> NSSize
    ) -> NSSize {
        let key = CandidatePanelLineSizeKey(
            kind: kind,
            column: column,
            candidateID: item.candidate.id,
            candidateSurface: item.candidate.surface,
            previewKey: previewKey
        )
        if let cached = lineSizeCache[key] {
            return cached
        }
        let measured = measure()
        lineSizeCache[key] = measured
        return measured
    }
}

private struct CandidatePanelLineSizeKey: Hashable {
    let kind: String
    let column: Int
    let candidateID: String
    let candidateSurface: String
    let previewKey: String
}

extension BilingualPreviewState {
    fileprivate var cacheKey: String {
        switch self {
        case .unavailable:
            return "unavailable"
        case .loading:
            return "loading"
        case .ready(let text):
            return "ready:\(text)"
        case .failed:
            return "failed"
        }
    }
}
