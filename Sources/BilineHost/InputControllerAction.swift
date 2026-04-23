import BilineCore
import Foundation

public enum InputControllerAction: Sendable, Equatable {
    case passThrough
    case consume
    case append(String)
    case appendLiteral(String)
    case insertText(String)
    case commitChineseAndInsert(String)
    case toggleLayer
    case deleteBackward
    case deleteRawBackwardByBlock
    case deleteRawToStart
    case commit
    case commitRawInput
    case cancel
    case moveColumn(SelectionDirection)
    case moveRawCursorByCharacter(SelectionDirection)
    case moveRawCursorByBlock(SelectionDirection)
    case moveRawCursorToStart
    case moveRawCursorToEnd
    case browseNextRow
    case browsePreviousRow
    case expandAndAdvanceRow
    case collapseToCompactAndSelectFirst
    case turnPage(PageDirection)
    case selectColumn(Int)
}
