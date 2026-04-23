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
                height: rawBufferRowHeight
            )
            drawRawBufferRow(in: rawRect)
            return
        }

        let widths = columnWidths()
        guard let (chineseStripRect, englishStripRect) = stripRects(columnWidths: widths) else {
            return
        }

        drawCandidateStrip(layer: .chinese, in: chineseStripRect, columnWidths: widths)
        if let englishStripRect {
            drawCandidateStrip(layer: .english, in: englishStripRect, columnWidths: widths)
        }
    }

    func drawCandidateStrip(
        layer: CandidatePanelLayer,
        in stripRect: NSRect,
        columnWidths: [CGFloat]
    ) {
        drawStripContainer(in: stripRect)
        for row in 0..<snapshot.visibleRowCount {
            drawCandidateRow(layer: layer, row: row, in: stripRect, columnWidths: columnWidths)
        }
    }

    func drawCandidateRow(
        layer: CandidatePanelLayer,
        row: Int,
        in stripRect: NSRect,
        columnWidths: [CGFloat]
    ) {
        let rowColumnCount = snapshot.items(inRow: row).count
        for column in 0..<rowColumnCount {
            if let item = snapshot.item(row: row, column: column) {
                let isSelected = row == snapshot.selectedRow && column == snapshot.selectedColumn
                let isActive = isSelected && activeLayer(for: layer) == snapshot.activeLayer
                guard
                    let tokenRect = candidateTokenRect(
                        layer: layer,
                        row: row,
                        column: column,
                        in: stripRect,
                        columnWidths: columnWidths
                    )
                else {
                    continue
                }

                drawSelectionPill(
                    in: tokenRect,
                    selected: isSelected,
                    active: isActive
                )

                drawLine(
                    candidateLine(
                        layer: layer,
                        column: column,
                        item: item,
                        selected: isSelected,
                        active: isActive
                    ),
                    in: inset(rect: tokenRect, insets: tokenPadding)
                )
            }
        }
    }

    func activeLayer(for layer: CandidatePanelLayer) -> ActiveLayer {
        switch layer {
        case .chinese:
            return .chinese
        case .english:
            return .english
        }
    }

    func drawRawBufferRow(in rect: NSRect) {
        drawStripContainer(in: rect)
        let lineSize = rawBufferLineSize(active: true)
        let tokenRect = NSRect(
            x: rect.minX + rowInsets.left,
            y: rect.minY + selectedTokenInset,
            width: lineSize.width + tokenPadding.left + tokenPadding.right,
            height: rect.height - selectedTokenInset * 2
        )

        drawSelectionPill(in: tokenRect, selected: true, active: true)
        drawLine(rawBufferLine(active: true), in: inset(rect: tokenRect, insets: tokenPadding))
    }

    func drawStripContainer(in rect: NSRect) {
        guard !rect.isEmpty else { return }
        let radius = roundedRectangleCornerRadius(for: rect)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor.windowBackgroundColor.withAlphaComponent(0.985).setFill()
        path.fill()
    }

    func drawSelectionPill(in rect: NSRect, selected: Bool, active: Bool) {
        guard selected else { return }

        let pillRect = NSRect(
            x: rect.minX + 2,
            y: rect.minY + 2,
            width: rect.width - 4,
            height: rect.height - 4
        )
        let radius = roundedRectangleCornerRadius(for: pillRect)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: radius, yRadius: radius)
        let fillColor: NSColor
        let strokeColor: NSColor

        if active {
            fillColor = NSColor.controlAccentColor.withAlphaComponent(0.92)
            strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.98)
        } else {
            fillColor = NSColor.controlAccentColor.withAlphaComponent(0.12)
            strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.30)
        }

        fillColor.setFill()
        path.fill()
        strokeColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func roundedRectangleCornerRadius(for rect: NSRect) -> CGFloat {
        let shortestSide = max(1, min(rect.width, rect.height))
        let scaled = shortestSide * 0.36
        return min(max(scaled, 8), 16)
    }

    func drawLine(_ line: NSAttributedString, in rect: NSRect) {
        let size = line.size()
        let drawingRect = NSRect(
            x: rect.minX,
            y: rect.midY - size.height / 2,
            width: min(size.width, rect.width),
            height: size.height
        )
        line.draw(in: drawingRect)
    }

    func candidateLine(
        layer: CandidatePanelLayer,
        column: Int,
        item: BilingualCandidateItem,
        selected: Bool,
        active: Bool
    ) -> NSAttributedString {
        switch layer {
        case .chinese:
            return candidateLine(column: column, item: item, selected: selected, active: active)
        case .english:
            return englishLine(column: column, item: item, selected: selected, active: active)
        }
    }

    func candidateLine(
        column: Int,
        item: BilingualCandidateItem,
        selected: Bool,
        active: Bool
    ) -> NSAttributedString {
        let text = "\(column + 1) \(item.candidate.surface)"
        let prefixLength = "\(column + 1) ".count
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: chineseFont,
                .foregroundColor: active ? NSColor.white : NSColor.labelColor,
            ]
        )
        attributed.addAttributes(
            [
                .font: candidateNumberFont,
                .foregroundColor: numberColor(selected: selected, active: active),
                .baselineOffset: numberBaselineOffset(for: chineseFont),
            ],
            range: NSRange(location: 0, length: prefixLength)
        )
        for run in fallbackFontResolver.runs(for: item.candidate.surface, baseFont: chineseFont) {
            attributed.addAttribute(
                .font,
                value: run.font,
                range: NSRange(
                    location: prefixLength + run.range.location, length: run.range.length)
            )
        }
        return attributed
    }

    func englishLine(
        column: Int,
        item: BilingualCandidateItem,
        selected: Bool,
        active: Bool
    ) -> NSAttributedString {
        let color: NSColor
        switch item.previewState {
        case .ready:
            color = active ? .white : .labelColor
        case .loading:
            color = active ? NSColor.white.withAlphaComponent(0.92) : .secondaryLabelColor
        case .failed, .unavailable:
            color = active ? NSColor.white.withAlphaComponent(0.85) : .tertiaryLabelColor
        }

        let text = "\(column + 1) \(englishPlaceholder(for: item.previewState))"
        let prefixLength = "\(column + 1) ".count
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: englishFont,
                .foregroundColor: color,
            ]
        )
        attributed.addAttributes(
            [
                .font: candidateNumberFont,
                .foregroundColor: numberColor(selected: selected, active: active),
                .baselineOffset: numberBaselineOffset(for: englishFont),
            ],
            range: NSRange(location: 0, length: prefixLength)
        )
        return attributed
    }

    func numberBaselineOffset(for contentFont: NSFont) -> CGFloat {
        max(0, (contentFont.capHeight - candidateNumberFont.capHeight) / 2)
    }

    func numberColor(selected: Bool, active: Bool) -> NSColor {
        if active {
            return NSColor.white.withAlphaComponent(0.9)
        }
        if selected {
            return NSColor.controlAccentColor.withAlphaComponent(0.88)
        }
        return NSColor.secondaryLabelColor
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
        let cursorLocation = min(
            max(0, snapshot.markedSelectionLocation), snapshot.displayRawInput.count)
        let prefix = String(snapshot.displayRawInput.prefix(cursorLocation))
        let suffix = String(snapshot.displayRawInput.dropFirst(cursorLocation))
        let text = prefix + "|" + suffix
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: rawBufferFont,
                .foregroundColor: active ? NSColor.white : NSColor.secondaryLabelColor,
            ]
        )
        attributed.addAttributes(
            [
                .font: rawBufferFont,
                .foregroundColor: active ? NSColor.white : NSColor.controlAccentColor,
            ],
            range: NSRange(location: prefix.count, length: 1)
        )
        return attributed
    }
}
