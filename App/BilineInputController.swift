import BilineCore
import BilineMocks
import BilinePreview
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

@objc(BilineInputController)
final class BilineInputController: IMKInputController {
    private let logger = Logger(
        subsystem: "io.github.xixiphus.inputmethod.BilineIME",
        category: "input-controller"
    )
    private let inputSession: BilineInputSession
    private var candidatesWindow: IMKCandidates?

    private weak var activeClient: AnyObject?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let settingsStore = DefaultSettingsStore()
        let previewCoordinator = PreviewCoordinator(
            provider: MockTranslationProvider(),
            debounce: .milliseconds(100)
        )
        self.inputSession = BilineInputSession(
            settingsStore: settingsStore,
            engineFactory: .demo(),
            previewCoordinator: previewCoordinator
        )
        super.init(server: server, delegate: delegate, client: inputClient)

        inputSession.onPreviewUpdate = { [weak self] previewText in
            self?.updateAnnotation(previewText)
        }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else {
            return false
        }

        activeClient = client as AnyObject

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

        if let digitIndex = candidateIndex(from: event), !inputSession.candidateStrings.isEmpty {
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

    override func candidates(_ sender: Any!) -> [Any]! {
        inputSession.candidateStrings
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let surface = candidateString?.string else { return }
        inputSession.updateSelection(for: surface)

        if let client = activeClient as? IMKTextInput {
            render(client: client)
        } else {
            updateAnnotation(inputSession.previewText)
        }
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let surface = candidateString?.string else { return }
        inputSession.updateSelection(for: surface)

        if let client = activeClient as? IMKTextInput {
            _ = commitSelection(using: client)
        }
    }

    override func commitComposition(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            _ = commitSelection(using: client)
        } else {
            inputSession.cancel()
        }
    }

    private func commitSelection(using client: IMKTextInput) -> Bool {
        guard let committedText = inputSession.commitSelection() else {
            return false
        }

        client.insertText(
            committedText,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        render(client: client)
        return true
    }

    private func render(client: IMKTextInput) {
        let candidatesWindow = resolveCandidatesWindow()
        let snapshot = inputSession.snapshot

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

        if snapshot.candidates.isEmpty {
            candidatesWindow.hide()
            updateAnnotation(nil)
            return
        }

        candidatesWindow.update()
        candidatesWindow.show()
        candidatesWindow.perform(
            #selector(IMKCandidates.selectCandidate(_:)),
            with: NSNumber(value: snapshot.selectedIndex))
        updateAnnotation(inputSession.previewText)
    }

    private func updateAnnotation(_ previewText: String?) {
        let candidatesWindow = resolveCandidatesWindow()
        let annotation = NSAttributedString(string: previewText ?? "")
        _ = candidatesWindow.perform(#selector(IMKCandidates.showAnnotation(_:)), with: annotation)
    }

    private func resolveCandidatesWindow() -> IMKCandidates {
        if let candidatesWindow {
            return candidatesWindow
        }

        let window: IMKCandidates = IMKCandidates(
            server: server(),
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )
        candidatesWindow = window
        return window
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
        return localIndex < inputSession.candidateStrings.count ? localIndex : nil
    }
}
