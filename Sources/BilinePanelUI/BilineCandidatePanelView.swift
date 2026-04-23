import BilineSession
import Cocoa

public final class BilineCandidatePanelView: NSView {
    public var snapshot: BilingualCompositionSnapshot = .idle {
        didSet {
            if shouldInvalidateLineSizeCache(oldValue: oldValue, newValue: snapshot) {
                lineSizeCache.removeAll()
            }
            needsDisplay = true
        }
    }

    public private(set) var theme: PanelTheme = PanelTheme()

    public override var isFlipped: Bool { true }

    let contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
    let blockSpacing: CGFloat = 7
    let rowSpacing: CGFloat = 1
    let columnSpacing: CGFloat = 18
    let rowInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 8)
    let tokenPadding = NSEdgeInsets(top: 2, left: 7, bottom: 3, right: 9)
    let selectedTokenInset: CGFloat = 0
    let minimumColumnWidth: CGFloat = 34
    let segmentBreathingRoom: CGFloat = 2
    private let baseChineseFontSize: CGFloat = 22
    private let baseEnglishFontSize: CGFloat = 18
    private let baseCandidateNumberFontSize: CGFloat = 12
    private let baseRawBufferFontSize: CGFloat = 17
    var chineseFont: NSFont {
        NSFont.systemFont(ofSize: baseChineseFontSize * theme.clampedFontScale, weight: .semibold)
    }
    var englishFont: NSFont {
        NSFont.systemFont(ofSize: baseEnglishFontSize * theme.clampedFontScale, weight: .regular)
    }
    var rawBufferFont: NSFont {
        NSFont.monospacedSystemFont(
            ofSize: baseRawBufferFontSize * theme.clampedFontScale,
            weight: .regular
        )
    }
    var candidateNumberFont: NSFont {
        NSFont.systemFont(
            ofSize: baseCandidateNumberFontSize * theme.clampedFontScale,
            weight: .medium
        )
    }
    let fallbackFontResolver = SystemFallbackFontResolver()
    private var lineSizeCache: [CandidatePanelLineSizeKey: NSSize] = [:]

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func applyTheme(_ theme: PanelTheme) {
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

    public override func draw(_ dirtyRect: NSRect) {
        drawSnapshot()
    }

    private func shouldInvalidateLineSizeCache(
        oldValue: BilingualCompositionSnapshot,
        newValue: BilingualCompositionSnapshot
    ) -> Bool {
        if oldValue.rawInput != newValue.rawInput { return true }
        if oldValue.rawCursorIndex != newValue.rawCursorIndex { return true }
        if oldValue.markedSelectionLocation != newValue.markedSelectionLocation { return true }
        if oldValue.items.count != newValue.items.count { return true }
        for index in 0..<newValue.items.count {
            if oldValue.items[index].candidate.id != newValue.items[index].candidate.id {
                return true
            }
        }
        return false
    }

    func rawBufferLineSize(active: Bool) -> NSSize {
        rawBufferLine(active: active).size()
    }

    func candidateLineSize(column: Int, item: BilingualCandidateItem) -> NSSize {
        cachedLineSize(
            kind: "candidate",
            column: column,
            item: item,
            previewKey: ""
        ) {
            candidateLine(column: column, item: item, selected: false, active: false).size()
        }
    }

    func englishLineSize(column: Int, item: BilingualCandidateItem) -> NSSize {
        cachedLineSize(
            kind: "english",
            column: column,
            item: item,
            previewKey: item.previewState.cacheKey
        ) {
            englishLine(column: column, item: item, selected: false, active: false).size()
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
