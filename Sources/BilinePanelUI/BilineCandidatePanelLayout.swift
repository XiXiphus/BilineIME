import BilineSession
import Cocoa

enum CandidatePanelLayer {
    case chinese
    case english
}

public struct CandidatePanelLayout {
    public init() {}

    public func positionedFrame(size: NSSize, anchorRect: NSRect) -> NSRect {
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

extension BilineCandidatePanelView {
    public var preferredSize: NSSize {
        guard !snapshot.rawInput.isEmpty else {
            return NSSize(width: 360, height: 0)
        }

        if snapshot.items.isEmpty {
            let width = contentInsets.left + rawBufferRowPreferredWidth + contentInsets.right
            let height = contentInsets.top + rawBufferRowHeight + contentInsets.bottom
            return NSSize(width: ceil(width), height: ceil(height))
        }

        let widths = columnWidths()
        let rowCount = max(1, snapshot.visibleRowCount)
        let widestRowWidth = stripContentWidth(rowCount: rowCount, columnWidths: widths)
        let width =
            contentInsets.left
            + widestRowWidth
            + contentInsets.right
        let height =
            contentInsets.top
            + stripHeight(rowCount: rowCount)
            + (snapshot.showsEnglishCandidates
                ? blockSpacing + stripHeight(rowCount: rowCount)
                : 0)
            + contentInsets.bottom

        return NSSize(width: ceil(width), height: ceil(height))
    }

    var candidateRowHeight: CGFloat {
        let chineseHeight = chineseFont.ascender - chineseFont.descender
        let englishHeight = englishFont.ascender - englishFont.descender
        return ceil(max(chineseHeight, englishHeight)) + rowInsets.top + rowInsets.bottom
    }

    var rawBufferRowHeight: CGFloat {
        let rawHeight = rawBufferFont.ascender - rawBufferFont.descender
        return max(candidateRowHeight, ceil(rawHeight) + rowInsets.top + rowInsets.bottom)
    }

    var rawBufferRowPreferredWidth: CGFloat {
        let textWidth = rawBufferLineSize(active: true).width
        return rowInsets.left + textWidth + tokenPadding.left + tokenPadding.right
            + segmentBreathingRoom
            + rowInsets.right
    }

    func stripHeight(rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return 0 }
        return CGFloat(rowCount) * candidateRowHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
    }

    func stripContentWidth(rowCount: Int, columnWidths: [CGFloat]) -> CGFloat {
        (0..<rowCount)
            .map { row in totalWidth(forRow: row, columnWidths: columnWidths) }
            .max() ?? 0
    }

    func stripRects(columnWidths: [CGFloat]) -> (chinese: NSRect, english: NSRect?)? {
        let rowCount = snapshot.visibleRowCount
        guard rowCount > 0 else { return nil }

        let containerWidth = stripContentWidth(rowCount: rowCount, columnWidths: columnWidths)
        let chineseStripRect = NSRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: containerWidth,
            height: stripHeight(rowCount: rowCount)
        )
        let englishStripRect: NSRect? =
            snapshot.showsEnglishCandidates
            ? NSRect(
                x: contentInsets.left,
                y: chineseStripRect.maxY + blockSpacing,
                width: containerWidth,
                height: stripHeight(rowCount: rowCount)
            )
            : nil

        return (chineseStripRect, englishStripRect)
    }

    func columnWidths() -> [CGFloat] {
        let maxVisibleColumns =
            (0..<snapshot.visibleRowCount)
            .map { snapshot.items(inRow: $0).count }
            .max() ?? 0
        guard maxVisibleColumns > 0 else { return [] }

        var widths = Array(repeating: CGFloat.zero, count: maxVisibleColumns)

        for column in 0..<maxVisibleColumns {
            for row in 0..<snapshot.visibleRowCount {
                guard let item = snapshot.item(row: row, column: column) else { continue }
                let chineseWidth = candidateTokenWidth(
                    layer: .chinese,
                    column: column,
                    item: item
                )
                let englishWidth =
                    snapshot.showsEnglishCandidates
                    ? candidateTokenWidth(layer: .english, column: column, item: item)
                    : 0
                widths[column] = max(widths[column], ceil(max(chineseWidth, englishWidth)))
            }

            widths[column] = max(widths[column], minimumColumnWidth)
        }

        return widths
    }

    func candidateTokenWidth(
        layer: CandidatePanelLayer,
        column: Int,
        item: BilingualCandidateItem
    ) -> CGFloat {
        let lineWidth: CGFloat
        switch layer {
        case .chinese:
            lineWidth = candidateLineSize(column: column, item: item).width
        case .english:
            lineWidth = englishLineSize(column: column, item: item).width
        }
        return ceil(lineWidth) + tokenPadding.left + tokenPadding.right + segmentBreathingRoom
    }

    func rowRect(in stripRect: NSRect, row: Int) -> NSRect {
        NSRect(
            x: stripRect.minX,
            y: stripRect.minY + CGFloat(row) * (candidateRowHeight + rowSpacing),
            width: stripRect.width,
            height: candidateRowHeight
        )
    }

    func candidateTokenRect(
        layer: CandidatePanelLayer,
        row: Int,
        column: Int,
        in stripRect: NSRect,
        columnWidths: [CGFloat]
    ) -> NSRect? {
        guard
            column >= 0,
            column < columnWidths.count,
            let item = snapshot.item(row: row, column: column)
        else {
            return nil
        }

        let rowRect = rowRect(in: stripRect, row: row)
        let originX =
            rowRect.minX
            + rowInsets.left
            + columnWidths.prefix(column).reduce(0, +)
            + CGFloat(column) * columnSpacing
        let width = min(columnWidths[column], candidateTokenWidth(layer: layer, column: column, item: item))
        let height = max(1, rowRect.height - selectedTokenInset * 2)

        return NSRect(
            x: originX,
            y: rowRect.midY - height / 2,
            width: width,
            height: height
        )
    }

    func totalWidth(forRow row: Int, columnWidths: [CGFloat]) -> CGFloat {
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

    func inset(rect: NSRect, insets: NSEdgeInsets) -> NSRect {
        NSRect(
            x: rect.minX + insets.left,
            y: rect.minY + insets.top,
            width: rect.width - insets.left - insets.right,
            height: rect.height - insets.top - insets.bottom
        )
    }
}
