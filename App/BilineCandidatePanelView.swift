import BilineSession
import Cocoa

final class BilineCandidatePanelView: NSView {
    var snapshot: BilingualCompositionSnapshot = .idle {
        didSet {
            if shouldInvalidateLineSizeCache(oldValue: oldValue, newValue: snapshot) {
                lineSizeCache.removeAll()
            }
            needsDisplay = true
        }
    }

    private(set) var theme: PanelTheme = PanelTheme()

    override var isFlipped: Bool { true }

    let contentInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    let blockSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 4
    let columnSpacing: CGFloat = 6
    let rowInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    let segmentPadding = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
    let minimumColumnWidth: CGFloat = 28
    let segmentBreathingRoom: CGFloat = 2
    private let baseChineseFontSize: CGFloat = 16
    private let baseEnglishFontSize: CGFloat = 13
    var chineseFont: NSFont {
        NSFont.systemFont(ofSize: baseChineseFontSize * theme.clampedFontScale, weight: .semibold)
    }
    var englishFont: NSFont {
        NSFont.systemFont(ofSize: baseEnglishFontSize * theme.clampedFontScale, weight: .regular)
    }
    let fallbackFontResolver = SystemFallbackFontResolver()
    private var lineSizeCache: [CandidatePanelLineSizeKey: NSSize] = [:]

    func applyTheme(_ theme: PanelTheme) {
        guard self.theme != theme else { return }
        let fontScaleChanged = self.theme.clampedFontScale != theme.clampedFontScale
        self.theme = theme
        if fontScaleChanged {
            lineSizeCache.removeAll()
        }
        if let appearance = theme.appearance() {
            self.appearance = appearance
        } else {
            self.appearance = nil
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSnapshot()
    }

    private func shouldInvalidateLineSizeCache(
        oldValue: BilingualCompositionSnapshot,
        newValue: BilingualCompositionSnapshot
    ) -> Bool {
        if oldValue.rawInput != newValue.rawInput { return true }
        if oldValue.items.count != newValue.items.count { return true }
        for index in 0..<newValue.items.count {
            if oldValue.items[index].candidate.id != newValue.items[index].candidate.id {
                return true
            }
        }
        return false
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
