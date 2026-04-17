import BilineSession
import Cocoa

final class BilineCandidatePanelController {
    private let panel: CandidatePanelWindow
    private let contentView: BilineCandidatePanelView

    init() {
        self.contentView = BilineCandidatePanelView(frame: .zero)
        self.panel = CandidatePanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
    }

    func render(
        snapshot: BilingualCompositionSnapshot,
        anchorRect: NSRect,
        windowLevel: NSWindow.Level
    ) {
        guard snapshot.isComposing, !snapshot.items.isEmpty else {
            hide()
            return
        }

        contentView.snapshot = snapshot
        let panelSize = contentView.preferredSize
        let panelFrame = positionedFrame(size: panelSize, anchorRect: anchorRect)
        panel.level = windowLevel
        panel.setFrame(panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionedFrame(size: NSSize, anchorRect: NSRect) -> NSRect {
        let spacing: CGFloat = 4
        var origin = NSPoint(x: anchorRect.minX, y: anchorRect.minY - size.height - spacing)

        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchorRect) }) {
            let visibleFrame = screen.visibleFrame.insetBy(dx: 8, dy: 8)
            if origin.y < visibleFrame.minY {
                origin.y = min(anchorRect.maxY + spacing, visibleFrame.maxY - size.height)
            }
            origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width)
            origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
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

    private let contentInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
    private let groupSpacing: CGFloat = 10
    private let languageRowSpacing: CGFloat = 6
    private let columnSpacing: CGFloat = 6
    private let rowInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    private let segmentPadding = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
    private let minimumColumnWidth: CGFloat = 28
    private let segmentBreathingRoom: CGFloat = 2
    private let chineseFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
    private let englishFont = NSFont.systemFont(ofSize: 13, weight: .regular)

    override var intrinsicContentSize: NSSize {
        preferredSize
    }

    var preferredSize: NSSize {
        guard !snapshot.items.isEmpty else {
            return NSSize(width: 360, height: 0)
        }

        let widths = columnWidths()
        let rowCount = max(1, snapshot.visibleRowCount)
        let widestRowWidth = (0..<rowCount)
            .map { row in totalWidth(forRow: row, columnWidths: widths) }
            .max() ?? 0
        let width = contentInsets.left
            + widestRowWidth
            + contentInsets.right
        let height = contentInsets.top
            + CGFloat(rowCount) * groupHeight
            + CGFloat(max(0, rowCount - 1)) * groupSpacing
            + contentInsets.bottom

        return NSSize(width: ceil(width), height: ceil(height))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !snapshot.items.isEmpty else { return }

        let widths = columnWidths()
        let rowCount = snapshot.visibleRowCount
        guard rowCount > 0 else { return }

        for row in 0..<rowCount {
            drawCandidateGroup(row: row, columnWidths: widths)
        }
    }

    private var chineseRowHeight: CGFloat {
        ceil(chineseFont.ascender - chineseFont.descender) + rowInsets.top + rowInsets.bottom
    }

    private var englishRowHeight: CGFloat {
        ceil(englishFont.ascender - englishFont.descender) + rowInsets.top + rowInsets.bottom
    }

    private var groupHeight: CGFloat {
        chineseRowHeight + languageRowSpacing + englishRowHeight
    }

    private func columnWidths() -> [CGFloat] {
        let maxVisibleColumns = (0..<snapshot.visibleRowCount)
            .map { snapshot.items(inRow: $0).count }
            .max() ?? 0
        guard maxVisibleColumns > 0 else { return [] }

        var widths = Array(repeating: CGFloat.zero, count: maxVisibleColumns)

        for column in 0..<maxVisibleColumns {
            for row in 0..<snapshot.visibleRowCount {
                guard let item = snapshot.item(row: row, column: column) else { continue }
                let chineseWidth = candidateLine(column: column, item: item, active: false).size().width
                let englishWidth = englishLine(column: column, item: item, active: false).size().width
                let contentWidth = ceil(max(chineseWidth, englishWidth))
                let fittedWidth = contentWidth
                    + segmentPadding.left
                    + segmentPadding.right
                    + segmentBreathingRoom
                widths[column] = max(widths[column], fittedWidth)
            }

            widths[column] = max(widths[column], minimumColumnWidth)
        }

        return widths
    }

    private func drawCandidateGroup(row: Int, columnWidths: [CGFloat]) {
        let originY = contentInsets.top + CGFloat(row) * (groupHeight + groupSpacing)
        let totalWidth = totalWidth(forRow: row, columnWidths: columnWidths)
        let chineseRowRect = NSRect(
            x: contentInsets.left,
            y: originY,
            width: totalWidth,
            height: chineseRowHeight
        )
        let englishRowRect = NSRect(
            x: contentInsets.left,
            y: chineseRowRect.maxY + languageRowSpacing,
            width: totalWidth,
            height: englishRowHeight
        )

        drawRowContainer(in: chineseRowRect)
        drawRowContainer(in: englishRowRect)

        var originX = chineseRowRect.minX + rowInsets.left
        let rowColumnCount = snapshot.items(inRow: row).count
        for column in 0..<rowColumnCount {
            let width = columnWidths[column]
            let segmentRect = NSRect(x: originX, y: 0, width: width, height: 0)

            if let item = snapshot.item(row: row, column: column) {
                let isSelected = row == snapshot.selectedRow && column == snapshot.selectedColumn
                let isChineseActive = isSelected && snapshot.activeLayer == .chinese
                let isEnglishActive = isSelected && snapshot.activeLayer == .english

                let chineseSegmentRect = NSRect(
                    x: segmentRect.minX,
                    y: chineseRowRect.minY + rowInsets.top / 2,
                    width: segmentRect.width,
                    height: chineseRowRect.height - rowInsets.top
                )
                let englishSegmentRect = NSRect(
                    x: segmentRect.minX,
                    y: englishRowRect.minY + rowInsets.top / 2,
                    width: segmentRect.width,
                    height: englishRowRect.height - rowInsets.top
                )

                drawSelectionPill(
                    in: chineseSegmentRect,
                    selected: isSelected,
                    active: isChineseActive
                )
                drawSelectionPill(
                    in: englishSegmentRect,
                    selected: isSelected,
                    active: isEnglishActive
                )

                candidateLine(column: column, item: item, active: isChineseActive).draw(
                    in: inset(rect: chineseSegmentRect, insets: segmentPadding)
                )
                englishLine(column: column, item: item, active: isEnglishActive).draw(
                    in: inset(rect: englishSegmentRect, insets: segmentPadding)
                )
            }

            originX += width + columnSpacing
        }
    }

    private func totalWidth(forRow row: Int, columnWidths: [CGFloat]) -> CGFloat {
        let rowColumnCount = snapshot.items(inRow: row).count
        guard rowColumnCount > 0 else {
            return rowInsets.left + rowInsets.right
        }

        let rowWidths = columnWidths.prefix(rowColumnCount)
        return rowInsets.left
            + rowWidths.reduce(0, +)
            + CGFloat(max(0, rowColumnCount - 1)) * columnSpacing
            + rowInsets.right
    }

    private func drawRowContainer(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawSelectionPill(in rect: NSRect, selected: Bool, active: Bool) {
        guard selected else { return }

        let pillRect = NSRect(
            x: rect.minX + 2,
            y: rect.minY + 2,
            width: rect.width - 4,
            height: rect.height - 4
        )
        let path = NSBezierPath(roundedRect: pillRect, xRadius: 12, yRadius: 12)
        let fillColor: NSColor
        let strokeColor: NSColor

        if active {
            fillColor = NSColor.controlAccentColor.withAlphaComponent(0.92)
            strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.98)
        } else {
            fillColor = NSColor.controlAccentColor.withAlphaComponent(0.10)
            strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.24)
        }

        fillColor.setFill()
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func candidateLine(
        column: Int,
        item: BilingualCandidateItem,
        active: Bool
    ) -> NSAttributedString {
        NSAttributedString(
            string: "\(column + 1) \(item.candidate.surface)",
            attributes: [
                .font: chineseFont,
                .foregroundColor: active ? NSColor.white : NSColor.labelColor,
            ]
        )
    }

    private func englishLine(
        column: Int,
        item: BilingualCandidateItem,
        active: Bool
    ) -> NSAttributedString {
        let color: NSColor
        switch item.previewState {
        case .ready:
            color = active ? .white : .secondaryLabelColor
        case .loading:
            color = active ? NSColor.white.withAlphaComponent(0.92) : .tertiaryLabelColor
        case .failed, .unavailable:
            color = active ? NSColor.white.withAlphaComponent(0.85) : .quaternaryLabelColor
        }

        return NSAttributedString(
            string: "\(column + 1) \(englishPlaceholder(for: item.previewState))",
            attributes: [
                .font: englishFont,
                .foregroundColor: color,
            ]
        )
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

    private func inset(rect: NSRect, insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: rect.minX + insets.left,
            y: rect.minY + insets.top,
            width: rect.width - insets.left - insets.right,
            height: rect.height - insets.top - insets.bottom
        )
    }
}
