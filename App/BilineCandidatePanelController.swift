import BilineSession
import Cocoa

final class BilineCandidatePanelController {
    private let panel: CandidatePanelWindow
    private let contentView: BilineCandidatePanelView

    init() {
        self.contentView = BilineCandidatePanelView(frame: .zero)
        self.panel = CandidatePanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
    }

    func render(snapshot: BilingualCompositionSnapshot, anchorRect: NSRect?) {
        guard snapshot.isComposing, !snapshot.items.isEmpty else {
            hide()
            return
        }

        contentView.snapshot = snapshot
        let panelSize = contentView.preferredSize
        let panelFrame = positionedFrame(size: panelSize, anchorRect: anchorRect)
        panel.setFrame(panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionedFrame(size: NSSize, anchorRect: NSRect?) -> NSRect {
        let spacing: CGFloat = 8
        let fallbackOrigin = NSPoint(x: NSEvent.mouseLocation.x + 12, y: NSEvent.mouseLocation.y - size.height - 12)
        var origin = fallbackOrigin

        if let anchorRect, !anchorRect.isEmpty {
            origin = NSPoint(x: anchorRect.minX, y: anchorRect.minY - size.height - spacing)
            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) }) {
                let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
                if origin.y < visibleFrame.minY {
                    origin.y = min(anchorRect.maxY + spacing, visibleFrame.maxY - size.height)
                }
                origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width)
                origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
            }
        }

        return NSRect(origin: origin, size: size)
    }
}

private final class CandidatePanelWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class BilineCandidatePanelView: NSView {
    var snapshot: BilingualCompositionSnapshot = .idle {
        didSet {
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }

    override var isFlipped: Bool { true }

    private let contentInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    private let rowSpacing: CGFloat = 10
    private let indexColumnWidth: CGFloat = 24
    private let textGap: CGFloat = 10
    private let lineSpacing: CGFloat = 4
    private let lineInsets = NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
    private let chineseFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
    private let englishFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    private let indexFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)

    var preferredSize: NSSize {
        guard !snapshot.items.isEmpty else {
            return NSSize(width: 320, height: 0)
        }

        let maxLineWidth = snapshot.items.enumerated().reduce(CGFloat(240)) { partialResult, pair in
            let itemWidth = max(
                candidateLine(for: pair.offset, item: pair.element).size().width,
                englishLine(for: pair.element).size().width
            )
            return max(partialResult, itemWidth)
        }

        let rowHeight = rowHeight
        let height = contentInsets.top
            + CGFloat(snapshot.items.count) * rowHeight
            + CGFloat(max(0, snapshot.items.count - 1)) * rowSpacing
            + contentInsets.bottom
        let width = contentInsets.left
            + indexColumnWidth
            + textGap
            + maxLineWidth
            + contentInsets.right
        return NSSize(width: ceil(width), height: ceil(height))
    }

    override var intrinsicContentSize: NSSize {
        preferredSize
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !snapshot.items.isEmpty else { return }

        let boundsPath = NSBezierPath(
            roundedRect: bounds,
            xRadius: 14,
            yRadius: 14
        )
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        boundsPath.fill()
        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        boundsPath.lineWidth = 1
        boundsPath.stroke()

        for (index, item) in snapshot.items.enumerated() {
            drawRow(for: index, item: item)
        }
    }

    private var rowHeight: CGFloat {
        chineseFont.ascender - chineseFont.descender
            + englishFont.ascender - englishFont.descender
            + lineInsets.top + lineInsets.bottom
            + lineSpacing
            + 10
    }

    private func drawRow(for index: Int, item: BilingualCandidateItem) {
        let originY = contentInsets.top + CGFloat(index) * (rowHeight + rowSpacing)
        let rowRect = NSRect(
            x: contentInsets.left,
            y: originY,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: rowHeight
        )

        let isSelected = index == snapshot.selectedIndex
        let isEnglishActive = isSelected && snapshot.activeLayer == .english
        let isChineseActive = isSelected && snapshot.activeLayer == .chinese

        if isSelected {
            let rowBackground = NSBezierPath(roundedRect: rowRect, xRadius: 10, yRadius: 10)
            NSColor.controlAccentColor.withAlphaComponent(0.08).setFill()
            rowBackground.fill()
            NSColor.controlAccentColor.withAlphaComponent(0.25).setStroke()
            rowBackground.lineWidth = 1
            rowBackground.stroke()
        }

        let indexRect = NSRect(
            x: rowRect.minX,
            y: rowRect.midY - 8,
            width: indexColumnWidth,
            height: 16
        )
        let indexString = NSAttributedString(
            string: indexLabel(for: index),
            attributes: [
                .font: indexFont,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        indexString.draw(in: indexRect)

        let textRect = NSRect(
            x: rowRect.minX + indexColumnWidth + textGap,
            y: rowRect.minY,
            width: rowRect.width - indexColumnWidth - textGap,
            height: rowRect.height
        )
        let chineseRect = NSRect(
            x: textRect.minX,
            y: textRect.minY,
            width: textRect.width,
            height: (rowRect.height - lineSpacing) / 2
        )
        let englishRect = NSRect(
            x: textRect.minX,
            y: chineseRect.maxY + lineSpacing,
            width: textRect.width,
            height: rowRect.height - chineseRect.height - lineSpacing
        )

        if isChineseActive {
            drawActiveLineBackground(in: chineseRect, alpha: 0.9)
        }
        if isEnglishActive {
            drawActiveLineBackground(in: englishRect, alpha: 0.78)
        }

        candidateLine(for: index, item: item).draw(
            in: inset(rect: chineseRect, insets: lineInsets)
        )
        englishLine(for: item, active: isEnglishActive).draw(
            in: inset(rect: englishRect, insets: lineInsets)
        )
    }

    private func candidateLine(for index: Int, item: BilingualCandidateItem) -> NSAttributedString {
        let text = "\(item.candidate.surface)"
        let isActive = index == snapshot.selectedIndex && snapshot.activeLayer == .chinese
        return NSAttributedString(
            string: text,
            attributes: [
                .font: chineseFont,
                .foregroundColor: isActive ? NSColor.white : NSColor.labelColor,
            ]
        )
    }

    private func englishLine(for item: BilingualCandidateItem, active: Bool = false) -> NSAttributedString {
        let color: NSColor
        switch item.previewState {
        case .ready:
            color = active ? .white : .secondaryLabelColor
        case .loading:
            color = active ? NSColor.white.withAlphaComponent(0.9) : .tertiaryLabelColor
        case .failed, .unavailable:
            color = active ? NSColor.white.withAlphaComponent(0.85) : .quaternaryLabelColor
        }

        return NSAttributedString(
            string: englishPlaceholder(for: item.previewState),
            attributes: [
                .font: englishFont,
                .foregroundColor: color,
            ]
        )
    }

    private func drawActiveLineBackground(in rect: NSRect, alpha: CGFloat) {
        let path = NSBezierPath(
            roundedRect: inset(rect: rect, insets: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)),
            xRadius: 8,
            yRadius: 8
        )
        NSColor.controlAccentColor.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    private func englishPlaceholder(for state: BilingualPreviewState) -> String {
        switch state {
        case .ready(let text):
            return text
        case .loading:
            return "Translating…"
        case .failed:
            return "Translation unavailable"
        case .unavailable:
            return "Preview unavailable"
        }
    }

    private func indexLabel(for index: Int) -> String {
        guard index < 9 else {
            return "•"
        }
        return "\(index + 1)"
    }

    private func inset(rect: NSRect, insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: rect.minX + insets.left,
            y: rect.minY + insets.top,
            width: rect.width - insets.left - insets.right,
            height: rect.height - insets.top - insets.bottom
        )
    }
}
