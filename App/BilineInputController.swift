import BilineCore
import BilineHost
import BilineMocks
import BilinePreview
import BilineSession
import Cocoa
@preconcurrency import InputMethodKit

@objc(BilineInputController)
final class BilineInputController: IMKInputController {
    private let inputSession: BilingualInputSession
    private let candidatePanel = BilineCandidatePanelController()
    private let textInputBridge = BilineTextInputBridge()
    private let eventRouter = InputControllerEventRouter()

    private weak var activeClient: AnyObject?

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

        let clientObject = client as AnyObject
        if activeClient !== clientObject {
            textInputBridge.clearAnchorCache()
            activeClient = clientObject
        }

        let action = eventRouter.route(
            event: InputControllerEvent(
                type: event.type == .flagsChanged ? .flagsChanged : .keyDown,
                keyCode: event.keyCode,
                characters: event.characters,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: modifierFlags(from: event)
            ),
            state: InputControllerState(
                isComposing: inputSession.snapshot.isComposing,
                canDeleteBackward: inputSession.canDeleteBackward,
                hasCandidates: inputSession.hasCandidates,
                compactColumnCount: inputSession.snapshot.compactColumnCount
            )
        )

        switch action {
        case .passThrough:
            return false
        case .consume:
            return true
        case .append(let text):
            inputSession.append(text: text)
        case .deleteBackward:
            inputSession.deleteBackward()
        case .commit:
            return commitSelection(using: client)
        case .cancel:
            inputSession.cancel()
            textInputBridge.clearAnchorCache()
        case .moveColumn(let direction):
            inputSession.moveColumn(direction)
        case .moveRow(let direction):
            inputSession.moveRow(direction)
        case .turnPage(let direction):
            inputSession.turnPage(direction)
        case .toggleLayer:
            inputSession.toggleActiveLayer()
        case .togglePresentation:
            inputSession.togglePresentationMode()
        case .selectColumn(let columnIndex):
            inputSession.selectColumn(at: columnIndex)
            return commitSelection(using: client)
        }

        render(client: client)
        return true
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            textInputBridge.clearComposition(in: client)
        }
        inputSession.cancel()
        textInputBridge.clearAnchorCache()
        candidatePanel.hide()
        eventRouter.reset()
        activeClient = nil
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            _ = commitSelection(using: client)
        } else {
            inputSession.cancel()
            textInputBridge.clearAnchorCache()
            candidatePanel.hide()
        }
    }

    private func commitSelection(using client: IMKTextInput) -> Bool {
        guard let committedText = inputSession.commitSelection() else {
            render(client: client)
            return inputSession.snapshot.isComposing
        }

        textInputBridge.insertCommittedText(committedText, into: client)
        textInputBridge.clearAnchorCache()
        render(client: client)
        return true
    }

    private func render(
        client: IMKTextInput,
        snapshot: BilingualCompositionSnapshot? = nil
    ) {
        let snapshot = snapshot ?? inputSession.snapshot
        textInputBridge.render(
            snapshot: snapshot,
            client: client,
            candidatePanel: candidatePanel
        )
    }

    private func modifierFlags(from event: NSEvent) -> InputModifierFlags {
        var flags: InputModifierFlags = []
        if event.modifierFlags.contains(.shift) {
            flags.insert(.shift)
        }
        if event.modifierFlags.contains(.command) {
            flags.insert(.command)
        }
        return flags
    }
}
