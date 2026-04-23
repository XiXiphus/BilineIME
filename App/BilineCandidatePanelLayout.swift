import Cocoa

struct CandidatePanelLayout {
    func positionedFrame(size: NSSize, anchorRect: NSRect) -> NSRect {
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
    var preferredSize: NSSize {
        guard !snapshot.rawInput.isEmpty else {
            return NSSize(width: 360, height: 0)
        }

        if snapshot.items.isEmpty {
            let width = contentInsets.left + rawBufferRowPreferredWidth + contentInsets.right
            let height = contentInsets.top + chineseRowHeight + contentInsets.bottom
            return NSSize(width: ceil(width), height: ceil(height))
        }

        let widths = columnWidths()
        let rowCount = max(1, snapshot.visibleRowCount)
        let widestRowWidth = blockContentWidth(rowCount: rowCount, columnWidths: widths)
        let width =
            contentInsets.left
            + widestRowWidth
            + contentInsets.right
        let height =
            contentInsets.top
            + blockHeight(rowHeight: chineseRowHeight, rowCount: rowCount)
            + (snapshot.showsEnglishCandidates
                ? blockSpacing + blockHeight(rowHeight: englishRowHeight, rowCount: rowCount)
                : 0)
            + contentInsets.bottom

        return NSSize(width: ceil(width), height: ceil(height))
    }

    var chineseRowHeight: CGFloat {
        ceil(chineseFont.ascender - chineseFont.descender) + rowInsets.top + rowInsets.bottom
    }

    var englishRowHeight: CGFloat {
        ceil(englishFont.ascender - englishFont.descender) + rowInsets.top + rowInsets.bottom
    }

    var rawBufferRowPreferredWidth: CGFloat {
        let textWidth = rawBufferLineSize(active: true).width
        return rowInsets.left + textWidth + segmentPadding.left + segmentPadding.right + 4
            + rowInsets.right
    }

    func blockHeight(rowHeight: CGFloat, rowCount: Int) -> CGFloat {
        guard rowCount > 0 else { return 0 }
        return CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * rowSpacing
    }

    func blockContentWidth(rowCount: Int, columnWidths: [CGFloat]) -> CGFloat {
        (0..<rowCount)
            .map { row in totalWidth(forRow: row, columnWidths: columnWidths) }
            .max() ?? 0
    }

    func blockRects(columnWidths: [CGFloat]) -> (chinese: NSRect, english: NSRect?)? {
        let rowCount = snapshot.visibleRowCount
        guard rowCount > 0 else { return nil }

        let containerWidth = blockContentWidth(rowCount: rowCount, columnWidths: columnWidths)
        let chineseBlockRect = NSRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: containerWidth,
            height: blockHeight(rowHeight: chineseRowHeight, rowCount: rowCount)
        )
        let englishBlockRect: NSRect? =
            snapshot.showsEnglishCandidates
            ? NSRect(
                x: contentInsets.left,
                y: chineseBlockRect.maxY + blockSpacing,
                width: containerWidth,
                height: blockHeight(rowHeight: englishRowHeight, rowCount: rowCount)
            )
            : nil

        return (chineseBlockRect, englishBlockRect)
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
                let chineseWidth = candidateLineSize(column: column, item: item).width
                let englishWidth = snapshot.showsEnglishCandidates
                    ? englishLineSize(column: column, item: item).width
                    : 0
                let contentWidth = ceil(max(chineseWidth, englishWidth))
                let fittedWidth =
                    contentWidth
                    + segmentPadding.left
                    + segmentPadding.right
                    + segmentBreathingRoom
                widths[column] = max(widths[column], fittedWidth)
            }

            widths[column] = max(widths[column], minimumColumnWidth)
        }

        return widths
    }

    func rowRect(in blockRect: NSRect, row: Int, rowHeight: CGFloat) -> NSRect {
        NSRect(
            x: blockRect.minX,
            y: blockRect.minY + CGFloat(row) * (rowHeight + rowSpacing),
            width: blockRect.width,
            height: rowHeight
        )
    }

    func segmentDrawingRect(
        row: Int,
        column: Int,
        in blockRect: NSRect,
        rowHeight: CGFloat,
        columnWidths: [CGFloat]
    ) -> NSRect? {
        let rowColumnCount = snapshot.items(inRow: row).count
        guard column >= 0, column < rowColumnCount, column < columnWidths.count else {
            return nil
        }

        let rowRect = rowRect(in: blockRect, row: row, rowHeight: rowHeight)
        let originX =
            rowRect.minX
            + rowInsets.left
            + columnWidths.prefix(column).reduce(0, +)
            + CGFloat(column) * columnSpacing
        let width = columnWidths[column]

        return NSRect(
            x: originX,
            y: rowRect.minY + rowInsets.top / 2,
            width: width,
            height: rowRect.height - rowInsets.top
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
