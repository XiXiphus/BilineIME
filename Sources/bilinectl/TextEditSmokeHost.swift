import BilineOperations
import Foundation

final class TextEditSmokeHost {
    private let runner: any CommandRunning
    private let fileManager: FileManager

    init(runner: any CommandRunning, fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    func preflight() throws {
        _ = try runAppleScript(
            """
            tell application "System Events"
                return UI elements enabled
            end tell
            """
        )
        _ = try runAppleScript(
            """
            tell application "TextEdit"
                return name
            end tell
            """
        )
    }

    func prepareBlankDocument() throws {
        _ = try runAppleScript(
            """
            tell application "TextEdit"
                if it is running then
                    quit saving no
                end if
            end tell
            delay 0.5
            tell application "TextEdit"
                activate
                repeat 20 times
                    if (count of documents) > 0 then
                        exit repeat
                    end if
                    delay 0.1
                end repeat
                if (count of documents) = 0 then
                    make new document
                end if
                repeat while (count of documents) > 1
                    close last document saving no
                end repeat
                set text of front document to ""
            end tell
            delay 0.5
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                end tell
            end tell
            """
        )
        try focusTextArea()
        try requireSingleSession()
    }

    func resetFrontDocument() throws {
        _ = try runAppleScript(
            """
            tell application "TextEdit"
                activate
                if (count of documents) = 0 then
                    make new document
                end if
                repeat while (count of documents) > 1
                    close last document saving no
                end repeat
                set text of front document to ""
            end tell
            delay 0.2
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                end tell
            end tell
            """
        )
        try focusTextArea()
        try requireSingleSession()
    }

    func focusTextArea() throws {
        _ = try runAppleScript(
            """
            tell application "System Events"
                tell process "TextEdit"
                    set frontmost to true
                    repeat 20 times
                        if exists window 1 then
                            exit repeat
                        end if
                        delay 0.1
                    end repeat
                    repeat 20 times
                        if exists text area 1 of scroll area 1 of window 1 then
                            click text area 1 of scroll area 1 of window 1
                            exit repeat
                        end if
                        delay 0.1
                    end repeat
                end tell
            end tell
            """
        )
    }

    func requireSingleSession() throws {
        let documentCount = try runAppleScript(
            """
            tell application "TextEdit"
                return count of documents
            end tell
            """
        )
        guard documentCount == "1" else {
            throw HostSmokeError.preflightFailed(
                "Host smoke requires exactly one TextEdit document/session. Found \(documentCount). Close or restart TextEdit instead of opening multiple windows."
            )
        }
    }

    func documentCount() throws -> String {
        try runAppleScript(
            """
            tell application "TextEdit"
                return count of documents
            end tell
            """
        )
    }

    func isTextAreaFocused() throws -> String {
        try runAppleScript(
            """
            tell application "System Events"
                tell process "TextEdit"
                    if exists text area 1 of scroll area 1 of window 1 then
                        return focused of text area 1 of scroll area 1 of window 1
                    end if
                end tell
            end tell
            return false
            """
        )
    }

    func typeText(_ text: String) throws {
        for character in text {
            guard let action = HostSmokeKeyboardMap.keyCodes[character.lowercased().first!] else {
                throw HostSmokeError.automationFailed(
                    "Unsupported smoke typing character: \(character)")
            }
            try press(action)
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    func press(_ action: HostSmokeKeyAction) throws {
        let modifierClause: String
        if action.modifiers.isEmpty {
            modifierClause = ""
        } else {
            modifierClause = " using {\(action.modifiers.joined(separator: ", "))}"
        }
        _ = try runAppleScript(
            """
            tell application "System Events"
                key code \(action.keyCode)\(modifierClause)
            end tell
            """
        )
    }

    func frontDocumentText() throws -> String {
        try runAppleScript(
            """
            tell application "TextEdit"
                return text of front document
            end tell
            """
        )
    }

    private func runAppleScript(_ source: String) throws -> String {
        let scriptURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("applescript")
        try source.write(to: scriptURL, atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: scriptURL) }
        let result = try runner.run("/usr/bin/osascript", [scriptURL.path], allowFailure: false)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
