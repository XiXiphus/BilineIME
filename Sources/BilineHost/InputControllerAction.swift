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
    case commit
    case commitRawInput
    case cancel
    case moveColumn(SelectionDirection)
    case browseNextRow
    case browsePreviousRow
    case expandAndAdvanceRow
    case collapseToCompactAndSelectFirst
    case turnPage(PageDirection)
    case selectColumn(Int)
}
