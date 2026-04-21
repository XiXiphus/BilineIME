import BilineSession
import Cocoa

final class BilineCandidatePanelView: NSView {
    var snapshot: BilingualCompositionSnapshot = .idle {
        didSet {
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

    override var intrinsicContentSize: NSSize {
        preferredSize
    }

    override func draw(_ dirtyRect: NSRect) {
        drawSnapshot()
    }
}
