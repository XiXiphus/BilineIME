import BilineCore
import BilineHost
import BilineMocks
import BilinePreview
import BilineSession
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

@objc(BilineInputController)
final class BilineInputController: IMKInputController {
    #if DEBUG
        private enum SmokeDefaults {
            static let previewDelayMs = "SmokePreviewDelayMs"
            static let previewDebounceMs = "SmokePreviewDebounceMs"

            static func milliseconds(forKey key: String, fallback: Int) -> Duration {
                let value = UserDefaults.standard.integer(forKey: key)
                let resolved = value > 0 ? value : fallback
                return .milliseconds(resolved)
            }
        }
    #endif

    private struct RoutedKeySignature: Equatable {
        let keyCode: UInt16
        let text: String
        let modifiersRawValue: Int
        let timestamp: TimeInterval
    }

    private let inputSession: BilingualInputSession
    private let candidatePanel = BilineCandidatePanelController()
    private let textInputBridge = BilineTextInputBridge()
    private let eventRouter = InputControllerEventRouter()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
        category: "input-controller"
    )
    #if DEBUG
        private let smokeLogger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
            category: "smoke"
        )
    #endif

    private var activeClient: AnyObject?
    private var lastHandledKeySignature: RoutedKeySignature?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let settingsStore = DefaultSettingsStore()
        #if DEBUG
            let smokePreviewDelay = SmokeDefaults.milliseconds(
                forKey: SmokeDefaults.previewDelayMs,
                fallback: 800
            )
            let smokePreviewDebounce = SmokeDefaults.milliseconds(
                forKey: SmokeDefaults.previewDebounceMs,
                fallback: 100
            )
        #else
            let smokePreviewDelay: Duration = .zero
            let smokePreviewDebounce: Duration = .milliseconds(100)
        #endif
        let previewCoordinator = PreviewCoordinator(
            provider: MockTranslationProvider(delay: smokePreviewDelay),
            debounce: smokePreviewDebounce
        )
        self.inputSession = BilingualInputSession(
            settingsStore: settingsStore,
            engineFactory: FixtureCandidateEngineFactory.demo(),
            previewCoordinator: previewCoordinator
        )
        super.init(server: server, delegate: delegate, client: inputClient)

        inputSession.onSnapshotUpdate = { [weak self] snapshot in
            guard let self else {
                return
            }
            #if DEBUG
                self.emitSmokeTelemetry(snapshot: snapshot)
            #endif
            guard let client = self.activeClient as? IMKTextInput else {
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

    override func inputText(
        _ string: String!,
        key keyCode: Int,
        modifiers flags: Int,
        client sender: Any!
    ) -> Bool {
        guard let client = sender as? IMKTextInput else {
            return false
        }

        let clientObject = client as AnyObject
        if activeClient !== clientObject {
            textInputBridge.clearAnchorCache()
            activeClient = clientObject
        }

        let text = string ?? ""
        let modifiers = modifierFlags(fromRawValue: flags)
        let signature = RoutedKeySignature(
            keyCode: UInt16(truncatingIfNeeded: keyCode),
            text: text,
            modifiersRawValue: modifiers.rawValue,
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        if shouldSuppressDuplicate(signature) {
            return true
        }

        let handled = routeAndApply(
            event: InputControllerEvent(
                type: .keyDown,
                keyCode: UInt16(truncatingIfNeeded: keyCode),
                characters: text,
                charactersIgnoringModifiers: text,
                modifierFlags: modifiers
            ),
            client: client,
            loggingSource: "inputText"
        )

        if handled {
            rememberHandled(signature)
        }

        return handled
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

        if event.type == .keyDown {
            let signature = RoutedKeySignature(
                keyCode: event.keyCode,
                text: event.characters ?? event.charactersIgnoringModifiers ?? "",
                modifiersRawValue: modifierFlags(from: event).rawValue,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            if shouldSuppressDuplicate(signature) {
                return true
            }
        }

        let handled = routeAndApply(
            event: InputControllerEvent(
                type: event.type == .flagsChanged ? .flagsChanged : .keyDown,
                keyCode: event.keyCode,
                characters: event.characters,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: modifierFlags(from: event)
            ),
            client: client,
            loggingSource: "handle"
        )

        if handled, event.type == .keyDown {
            let signature = RoutedKeySignature(
                keyCode: event.keyCode,
                text: event.characters ?? event.charactersIgnoringModifiers ?? "",
                modifiersRawValue: modifierFlags(from: event).rawValue,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            rememberHandled(signature)
        }

        return handled
    }

    override func deactivateServer(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            textInputBridge.clearComposition(in: client)
        }
        inputSession.cancel()
        textInputBridge.clearAnchorCache()
        candidatePanel.hide()
        eventRouter.reset()
        lastHandledKeySignature = nil
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

    private func modifierFlags(fromRawValue rawValue: Int) -> InputModifierFlags {
        let cocoaFlags = NSEvent.ModifierFlags(rawValue: UInt(rawValue))
        var flags: InputModifierFlags = []
        if cocoaFlags.contains(.shift) {
            flags.insert(.shift)
        }
        if cocoaFlags.contains(.command) {
            flags.insert(.command)
        }
        return flags
    }

    private func routeAndApply(
        event: InputControllerEvent,
        client: IMKTextInput,
        loggingSource: StaticString
    ) -> Bool {
        let compositionMode: InputCompositionMode
        switch inputSession.compositionMode {
        case .candidateCompact:
            compositionMode = .candidateCompact
        case .candidateExpanded:
            compositionMode = .candidateExpanded
        case .rawBufferOnly:
            compositionMode = .rawBufferOnly
        }

        let action = eventRouter.route(
            event: event,
            state: InputControllerState(
                compositionMode: compositionMode,
                isComposing: inputSession.snapshot.isComposing,
                canDeleteBackward: inputSession.canDeleteBackward,
                hasCandidates: inputSession.hasCandidates,
                compactColumnCount: inputSession.snapshot.compactColumnCount,
                selectedRow: inputSession.snapshot.selectedRow,
                isExpandedPresentation: inputSession.snapshot.presentationMode == .expanded,
                hasEverExpandedInCurrentComposition: inputSession.hasEverExpandedInCurrentComposition
            )
        )

        #if DEBUG
            if inputSession.snapshot.isComposing, action == .passThrough {
                logger.info(
                    "[\(loggingSource, privacy: .public)] unhandled composing event type=\(String(describing: event.type), privacy: .public) keyCode=\(event.keyCode) chars=\(event.characters ?? "", privacy: .public) charsIgnoring=\(event.charactersIgnoringModifiers ?? "", privacy: .public) modifiers=\(event.modifierFlags.rawValue)"
                )
            }
        #endif

        switch action {
        case .passThrough:
            return false
        case .consume:
            render(client: client)
            return true
        case .append(let text):
            inputSession.append(text: text)
        case .appendLiteral(let text):
            inputSession.appendLiteral(text: text)
        case .toggleLayer:
            inputSession.toggleActiveLayer()
        case .commitChineseAndInsert(let text):
            let committedText = inputSession.commitChineseSelection()
            if let committedText, !committedText.isEmpty {
                textInputBridge.insertCommittedText(committedText, into: client)
            }
            textInputBridge.insertCommittedText(
                inputSession.renderCommittedText(text),
                into: client
            )
            textInputBridge.clearAnchorCache()
            render(client: client)
            return true
        case .deleteBackward:
            inputSession.deleteBackward()
        case .commit:
            return commitSelection(using: client)
        case .cancel:
            inputSession.cancel()
            textInputBridge.clearAnchorCache()
        case .moveColumn(let direction):
            inputSession.moveColumn(direction)
        case .browseNextRow:
            inputSession.browseNextRow()
        case .browsePreviousRow:
            inputSession.browsePreviousRow()
        case .expandAndAdvanceRow:
            inputSession.expandAndAdvanceRow()
        case .collapseToCompactAndSelectFirst:
            inputSession.collapseToCompactAndSelectFirst()
        case .turnPage(let direction):
            inputSession.turnPage(direction)
        case .selectColumn(let columnIndex):
            inputSession.selectColumn(at: columnIndex)
            return commitSelection(using: client)
        }

        render(client: client)
        return true
    }

    private func shouldSuppressDuplicate(_ signature: RoutedKeySignature) -> Bool {
        guard let previous = lastHandledKeySignature else {
            return false
        }

        let isFresh = signature.timestamp - previous.timestamp < 0.05
        let matches = signature.keyCode == previous.keyCode
            && signature.text == previous.text
            && signature.modifiersRawValue == previous.modifiersRawValue
        lastHandledKeySignature = nil
        return isFresh && matches
    }

    private func rememberHandled(_ signature: RoutedKeySignature) {
        lastHandledKeySignature = signature
    }

    #if DEBUG
        private func emitSmokeTelemetry(snapshot: BilingualCompositionSnapshot) {
            smokeLogger.notice(
                "SMOKE compositionMode=\(self.inputSession.compositionMode.rawValue, privacy: .public) presentationMode=\(snapshot.presentationMode.rawValue, privacy: .public) pageIndex=\(snapshot.pageIndex) selectedRow=\(snapshot.selectedRow) selectedColumn=\(snapshot.selectedColumn) activeLayer=\(snapshot.activeLayer.rawValue, privacy: .public) rawInput=\(self.smokeValue(snapshot.rawInput), privacy: .public) displayRawInput=\(self.smokeValue(snapshot.displayRawInput), privacy: .public) hasEverExpanded=\(self.inputSession.hasEverExpandedInCurrentComposition, privacy: .public) isComposing=\(snapshot.isComposing, privacy: .public) hasCandidates=\(!snapshot.items.isEmpty, privacy: .public)"
            )
        }

        private func smokeValue(_ value: String) -> String {
            value.isEmpty ? "<empty>" : value.replacingOccurrences(of: " ", with: "␠")
        }
    #endif
}
