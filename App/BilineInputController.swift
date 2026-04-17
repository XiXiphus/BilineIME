import BilineCore
import BilineMocks
import BilinePreview
import BilineSession
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

@objc(BilineInputController)
final class BilineInputController: IMKInputController {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
        category: "input-controller"
    )
    private let inputSession: BilingualInputSession
    private let candidatePanel = BilineCandidatePanelController()

    private weak var activeClient: AnyObject?
    private var isShiftPressed = false

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let settingsStore = DefaultSettingsStore()
        let previewCoordinator = PreviewCoordinator(
            provider: MockTranslationProvider(),
            debounce: .milliseconds(100)
        )
        self.inputSession = BilingualInputSession(
            settingsStore: settingsStore,
            engineFactory: FixtureCandidateEngineFactory.demo(),
            previewCoordinator: previewCoordinator
        )
        super.init(server: server, delegate: delegate, client: inputClient)

        inputSession.onSnapshotUpdate = { [weak self] snapshot in
            guard let self, let client = self.activeClient as? IMKTextInput else {
                return
            }
            self.render(client: client, snapshot: snapshot)
        }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }

    override func modes(_ sender: Any!) -> [AnyHashable: Any]! {
        Bundle.main.object(forInfoDictionaryKey: "ComponentInputModeDict") as? [AnyHashable: Any]
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else {
            return false
        }

        activeClient = client as AnyObject

        if event.type == .flagsChanged {
            return handleFlagsChanged(event, client: client)
        }

        if event.modifierFlags.contains(.command) {
            return false
        }

        switch event.keyCode {
        case 36, 49:
            return commitSelection(using: client)
        case 51:
            inputSession.deleteBackward()
            render(client: client)
            return true
        case 53:
            inputSession.cancel()
            render(client: client)
            return true
        case 123, 126:
            inputSession.moveSelection(.previous)
            render(client: client)
            return true
        case 124, 125:
            inputSession.moveSelection(.next)
            render(client: client)
            return true
        case 116:
            inputSession.turnPage(.previous)
            render(client: client)
            return true
        case 121:
            inputSession.turnPage(.next)
            render(client: client)
            return true
        default:
            break
        }

        if let digitIndex = candidateIndex(from: event), !inputSession.snapshot.items.isEmpty {
            inputSession.selectCandidate(at: digitIndex)
            return commitSelection(using: client)
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return false
        }

        let normalized = characters.filter { $0.isLetter || $0 == "'" }
        guard !normalized.isEmpty else {
            return false
        }

        inputSession.append(text: normalized)
        render(client: client)
        return true
    }

    override func deactivateServer(_ sender: Any!) {
        candidatePanel.hide()
        isShiftPressed = false
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            _ = commitSelection(using: client)
        } else {
            inputSession.cancel()
            candidatePanel.hide()
        }
    }

    private func commitSelection(using client: IMKTextInput) -> Bool {
        guard let committedText = inputSession.commitSelection() else {
            render(client: client)
            return inputSession.snapshot.isComposing
        }

        client.insertText(
            committedText,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        render(client: client)
        return true
    }

    private func render(
        client: IMKTextInput,
        snapshot: BilingualCompositionSnapshot? = nil
    ) {
        let snapshot = snapshot ?? inputSession.snapshot

        if snapshot.isComposing {
            client.setMarkedText(
                snapshot.markedText,
                selectionRange: NSRange(location: snapshot.markedText.count, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
        } else {
            client.setMarkedText(
                "",
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
        }

        if snapshot.items.isEmpty {
            candidatePanel.hide()
            return
        }

        candidatePanel.render(snapshot: snapshot, anchorRect: candidateAnchorRect(for: client))
    }

    private func handleFlagsChanged(_ event: NSEvent, client: IMKTextInput) -> Bool {
        guard event.keyCode == 56 || event.keyCode == 60 else {
            return false
        }

        guard inputSession.snapshot.isComposing else {
            isShiftPressed = event.modifierFlags.contains(.shift)
            return false
        }

        let isShiftDown = event.modifierFlags.contains(.shift)
        defer { isShiftPressed = isShiftDown }

        guard isShiftDown, !isShiftPressed else {
            return true
        }

        inputSession.toggleActiveLayer()
        render(client: client)
        return true
    }

    private func candidateAnchorRect(for client: IMKTextInput) -> NSRect? {
        guard let textClient = client as? NSTextInputClient else {
            return nil
        }

        var actualRange = NSRange(location: NSNotFound, length: 0)
        let selectedRange = textClient.selectedRange()
        let rect = textClient.firstRect(
            forCharacterRange: selectedRange,
            actualRange: &actualRange
        )
        return rect.isEmpty ? nil : rect
    }

    private func candidateIndex(from event: NSEvent) -> Int? {
        guard let characters = event.charactersIgnoringModifiers, characters.count == 1 else {
            return nil
        }

        guard let scalar = characters.unicodeScalars.first,
            CharacterSet.decimalDigits.contains(scalar),
            let value = Int(String(characters)),
            value >= 1
        else {
            return nil
        }

        let localIndex = value - 1
        return localIndex < inputSession.snapshot.items.count ? localIndex : nil
    }
}
