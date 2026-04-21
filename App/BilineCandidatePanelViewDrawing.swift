import BilineSession
import Cocoa

extension BilineCandidatePanelView {
    func drawSnapshot() {
        guard !snapshot.rawInput.isEmpty else { return }

        if snapshot.items.isEmpty {
            let rawRect = NSRect(
                x: contentInsets.left,
                y: contentInsets.top,
                width: rawBufferRowPreferredWidth,
                height: chineseRowHeight
            )
            drawRowContainer(in: rawRect)
            drawRawBufferRow(in: rawRect)
            return
        }

        let widths = columnWidths()
        guard let (chineseBlockRect, englishBlockRect) = blockRects(columnWidths: widths) else { return }
        let rowCount = snapshot.visibleRowCount

        drawRowContainer(in: chineseBlockRect)
        drawRowContainer(in: englishBlockRect)

        for row in 0..<rowCount {
            drawChineseRow(row: row, in: chineseBlockRect, columnWidths: widths)
            drawEnglishRow(row: row, in: englishBlockRect, columnWidths: widths)
        }
    }

    func drawChineseRow(row: Int, in blockRect: NSRect, columnWidths: [CGFloat]) {
        let rowColumnCount = snapshot.items(inRow: row).count
        for column in 0..<rowColumnCount {
            if let item = snapshot.item(row: row, column: column) {
                let isSelected = row == snapshot.selectedRow && column == snapshot.selectedColumn
                let isChineseActive = isSelected && snapshot.activeLayer == .chinese
                guard let segmentDrawingRect = segmentDrawingRect(
                    row: row,
                    column: column,
                    in: blockRect,
                    rowHeight: chineseRowHeight,
                    columnWidths: columnWidths
                ) else {
                    continue
                }

                drawSelectionPill(
                    in: segmentDrawingRect,
                    selected: isSelected,
                    active: isChineseActive
                )

                candidateLine(column: column, item: item, active: isChineseActive).draw(
                    in: inset(rect: segmentDrawingRect, insets: segmentPadding)
                )
            }
        }
    }

    func drawEnglishRow(row: Int, in blockRect: NSRect, columnWidths: [CGFloat]) {
        let rowColumnCount = snapshot.items(inRow: row).count
        for column in 0..<rowColumnCount {
            if let item = snapshot.item(row: row, column: column) {
                let isSelected = row == snapshot.selectedRow && column == snapshot.selectedColumn
                let isEnglishActive = isSelected && snapshot.activeLayer == .english
                guard let segmentDrawingRect = segmentDrawingRect(
                    row: row,
                    column: column,
                    in: blockRect,
                    rowHeight: englishRowHeight,
                    columnWidths: columnWidths
                ) else {
                    continue
                }

                drawSelectionPill(
                    in: segmentDrawingRect,
                    selected: isSelected,
                    active: isEnglishActive
                )

                englishLine(column: column, item: item, active: isEnglishActive).draw(
                    in: inset(rect: segmentDrawingRect, insets: segmentPadding)
                )
            }
        }
    }

    func drawRawBufferRow(in rect: NSRect) {
        let pillRect = NSRect(
            x: rect.minX + rowInsets.left,
            y: rect.minY + rowInsets.top / 2,
            width: rect.width - rowInsets.left - rowInsets.right,
            height: rect.height - rowInsets.top
        )

        drawSelectionPill(in: pillRect, selected: true, active: true)
        rawBufferLine(active: true).draw(in: inset(rect: pillRect, insets: segmentPadding))
    }

    func drawRowContainer(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.withAlphaComponent(0.97).setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func drawSelectionPill(in rect: NSRect, selected: Bool, active: Bool) {
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

    func candidateLine(
        column: Int,
        item: BilingualCandidateItem,
        active: Bool
    ) -> NSAttributedString {
        let text = "\(column + 1) \(item.candidate.surface)"
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: chineseFont,
                .foregroundColor: active ? NSColor.white : NSColor.labelColor,
            ]
        )
        let prefixLength = "\(column + 1) ".count
        for run in fallbackFontResolver.runs(for: item.candidate.surface, baseFont: chineseFont) {
            attributed.addAttribute(
                .font,
                value: run.font,
                range: NSRange(location: prefixLength + run.range.location, length: run.range.length)
            )
        }
        return attributed
    }

    func englishLine(
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

    func englishPlaceholder(for state: BilingualPreviewState) -> String {
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

    func rawBufferLine(active: Bool) -> NSAttributedString {
        NSAttributedString(
            string: snapshot.displayRawInput,
            attributes: [
                .font: chineseFont,
                .foregroundColor: active ? NSColor.white : NSColor.labelColor,
            ]
        )
    }
}
