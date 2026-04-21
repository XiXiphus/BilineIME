import BilineCore
import BilineHost
import BilineMocks
import BilinePreview
import BilineRime
import BilineSession
import BilineSettings
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
    private let characterForm: CharacterForm
    private let punctuationForm: PunctuationForm
    private let candidatePanel: BilineCandidatePanelController
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
        private let smokeFallbackFontResolver = SystemFallbackFontResolver()
        private let smokeCandidateFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
    #endif

    private var activeClient: AnyObject?
    private var lastHandledKeySignature: RoutedKeySignature?
    private var didLogFirstHandledKey = false
    private var didLogFirstComposingSnapshot = false

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let settingsStore = DefaultSettingsStore()
        self.characterForm = settingsStore.characterForm
        self.punctuationForm = settingsStore.punctuationForm
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

        let selectedTranslationProvider = TranslationProviderFactory.selectedProvider
        let configuredProvider = TranslationProviderFactory.configuredProvider()
        let provider: any TranslationProvider
        let schedulerConfiguration: TranslationPreviewScheduler.Configuration
        if let configuredProvider {
            provider = configuredProvider
            schedulerConfiguration = TranslationProviderFactory.aliyunSchedulerConfiguration
        } else if selectedTranslationProvider == "aliyun" {
            provider = UnavailableTranslationProvider()
            schedulerConfiguration = TranslationPreviewScheduler.Configuration()
        } else {
            #if DEBUG
                provider = MockTranslationProvider(delay: smokePreviewDelay)
                schedulerConfiguration = TranslationPreviewScheduler.Configuration()
            #else
                provider = UnavailableTranslationProvider()
                schedulerConfiguration = TranslationPreviewScheduler.Configuration()
            #endif
        }

        let previewCoordinator = PreviewCoordinator(
            provider: provider,
            debounce: smokePreviewDebounce,
            schedulerConfiguration: schedulerConfiguration
        )
        let engineFactory: any CandidateEngineFactory
        do {
            engineFactory = try BilinePinyinEngineFactory(
                fuzzyPinyinEnabled: settingsStore.fuzzyPinyinEnabled,
                characterForm: settingsStore.characterForm
            )
        } catch {
            fatalError("Unable to initialize Biline pinyin engine: \(error)")
        }
        self.inputSession = BilingualInputSession(
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            previewCoordinator: previewCoordinator
        )
        self.candidatePanel = MainThreadExecutor.sync {
            BilineCandidatePanelController()
        }
        super.init(server: server, delegate: delegate, client: inputClient)

        inputSession.onSnapshotUpdate = { [weak self] snapshot in
            guard let self else {
                return
            }
            #if DEBUG
                self.emitSmokeTelemetry(snapshot: snapshot)
            #endif
            if snapshot.isComposing, !self.didLogFirstComposingSnapshot {
                self.didLogFirstComposingSnapshot = true
                self.logger.info(
                    "First composing snapshot rawInput=\(snapshot.rawInput, privacy: .public) remainingRawInput=\(snapshot.remainingRawInput, privacy: .public) candidateCount=\(snapshot.items.count) activeLayer=\(snapshot.activeLayer.rawValue, privacy: .public)"
                )
            }
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
            switchActiveClient(to: clientObject)
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
            switchActiveClient(to: clientObject)
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
        textInputBridge.hide(candidatePanel: candidatePanel)
        if let client = activeClient as? IMKTextInput {
            textInputBridge.clearComposition(in: client)
        }
        inputSession.cancel()
        textInputBridge.clearAnchorCache()
        eventRouter.reset()
        lastHandledKeySignature = nil
        didLogFirstHandledKey = false
        didLogFirstComposingSnapshot = false
        activeClient = nil
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if let client = activeClient as? IMKTextInput {
            _ = commitSelection(using: client)
        } else {
            inputSession.cancel()
            textInputBridge.clearAnchorCache()
            textInputBridge.hide(candidatePanel: candidatePanel)
        }
    }

    private func commitSelection(using client: IMKTextInput) -> Bool {
        guard let committedText = inputSession.commitSelection() else {
            render(client: client)
            return inputSession.snapshot.isComposing
        }

        textInputBridge.insertCommittedText(committedText, into: client)
        let postSnapshot = inputSession.snapshot
        if !postSnapshot.isComposing {
            textInputBridge.clearAnchorCache()
        }
        #if DEBUG
            smokeLogger.notice(
                "SMOKE_COMMIT committedText=\(self.smokeValue(committedText), privacy: .public) postCommitRawInput=\(self.smokeValue(postSnapshot.rawInput), privacy: .public) isComposing=\(postSnapshot.isComposing, privacy: .public)"
            )
        #endif
        render(client: client, snapshot: postSnapshot)
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
        // Suppress the session's snapshot-update callback for the duration
        // of this sync key-event handling. Each routeAndApply call performs
        // exactly one explicit render at the end (or inside a commit
        // helper), so we do not want the session's per-mutation callback to
        // also fire and double-render through IMK/AppKit.
        inputSession.suppressSnapshotNotification = true
        defer { inputSession.suppressSnapshotNotification = false }

        // Snapshot session state once. The previous implementation acquired
        // the recursive state lock five separate times while building the
        // router state, which adds overhead and (more importantly) lets the
        // engine snapshot drift mid-construction if another thread mutates
        // it.
        let snapshot = inputSession.snapshot
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
                isComposing: snapshot.isComposing,
                canDeleteBackward: !snapshot.rawInput.isEmpty,
                hasCandidates: !snapshot.items.isEmpty,
                compactColumnCount: snapshot.compactColumnCount,
                punctuationForm: inputSession.punctuationForm,
                pageIndex: snapshot.pageIndex,
                selectedRow: snapshot.selectedRow,
                isExpandedPresentation: snapshot.presentationMode == .expanded,
                hasEverExpandedInCurrentComposition: inputSession
                    .hasEverExpandedInCurrentComposition,
                hasExplicitCandidateSelection: inputSession.hasExplicitCandidateSelection
            )
        )

        #if DEBUG
            if !didLogFirstHandledKey, event.type == .keyDown, action != .passThrough {
                didLogFirstHandledKey = true
                logger.info(
                    "First handled key keyCode=\(event.keyCode) chars=\(event.characters ?? "", privacy: .public) charsIgnoring=\(event.charactersIgnoringModifiers ?? "", privacy: .public) action=\(String(describing: action), privacy: .public)"
                )
            }
            if snapshot.isComposing, action == .passThrough {
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
        case .insertText(let text):
            textInputBridge.insertCommittedText(text, into: client)
            textInputBridge.clearAnchorCache()
            render(client: client)
            return true
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
            // Punctuation always finalizes composition; clear the anchor
            // cache so the next composing keystroke re-anchors against the
            // fresh caret position.
            textInputBridge.clearAnchorCache()
            render(client: client)
            return true
        case .deleteBackward:
            inputSession.deleteBackward()
        case .commit:
            return commitSelection(using: client)
        case .commitRawInput:
            return commitRawInput(using: client)
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

    private func commitRawInput(using client: IMKTextInput) -> Bool {
        guard let committedText = inputSession.commitRawInput() else {
            render(client: client)
            return inputSession.snapshot.isComposing
        }

        textInputBridge.insertCommittedText(committedText, into: client)
        let postSnapshot = inputSession.snapshot
        if !postSnapshot.isComposing {
            textInputBridge.clearAnchorCache()
        }
        render(client: client, snapshot: postSnapshot)
        return true
    }

    private func shouldSuppressDuplicate(_ signature: RoutedKeySignature) -> Bool {
        guard let previous = lastHandledKeySignature else {
            return false
        }

        let isFresh = signature.timestamp - previous.timestamp < 0.05
        let matches =
            signature.keyCode == previous.keyCode
            && signature.text == previous.text
            && signature.modifiersRawValue == previous.modifiersRawValue
        lastHandledKeySignature = nil
        return isFresh && matches
    }

    private func rememberHandled(_ signature: RoutedKeySignature) {
        lastHandledKeySignature = signature
    }

    private func switchActiveClient(to clientObject: AnyObject) {
        textInputBridge.hide(candidatePanel: candidatePanel)
        if let previousClient = activeClient as? IMKTextInput {
            textInputBridge.clearComposition(in: previousClient)
        }
        inputSession.cancel()
        textInputBridge.clearAnchorCache()
        eventRouter.reset()
        lastHandledKeySignature = nil
        didLogFirstComposingSnapshot = false
    }

    #if DEBUG
        private func emitSmokeTelemetry(snapshot: BilingualCompositionSnapshot) {
            let selectedItem = snapshot.item(
                row: snapshot.selectedRow,
                column: snapshot.selectedColumn
            )
            let selectedCandidate = selectedItem?.candidate.surface ?? "<none>"
            let selectedCandidateReading = selectedItem?.candidate.reading ?? "<none>"
            let selectedConsumedTokenCount = selectedItem?.candidate.consumedTokenCount ?? 0
            let selectedPreviewState =
                selectedItem.map { smokePreviewState($0.previewState) } ?? "<none>"
            let selectedEnglishText = selectedItem?.englishText ?? "<none>"
            let visibleCandidates = smokeCandidateList(snapshot)
            let schemaID = BilineAppPath.rimeSchemaID(characterForm: characterForm.rawValue)
            let userDictionaryName = BilineAppPath.rimeUserDictionaryName(
                characterForm: characterForm.rawValue)
            smokeLogger.notice(
                "SMOKE compositionMode=\(self.inputSession.compositionMode.rawValue, privacy: .public) presentationMode=\(snapshot.presentationMode.rawValue, privacy: .public) pageIndex=\(snapshot.pageIndex) selectedRow=\(snapshot.selectedRow) selectedColumn=\(snapshot.selectedColumn) activeLayer=\(snapshot.activeLayer.rawValue, privacy: .public) rawInput=\(self.smokeValue(snapshot.rawInput), privacy: .public) remainingRawInput=\(self.smokeValue(snapshot.remainingRawInput), privacy: .public) displayRawInput=\(self.smokeValue(snapshot.displayRawInput), privacy: .public) candidateCount=\(snapshot.items.count) selectedCandidate=\(self.smokeValue(selectedCandidate), privacy: .public) selectedCandidateReading=\(self.smokeValue(selectedCandidateReading), privacy: .public) selectedConsumedTokenCount=\(selectedConsumedTokenCount) selectedPreviewState=\(selectedPreviewState, privacy: .public) selectedEnglishText=\(self.smokeValue(selectedEnglishText), privacy: .public) characterForm=\(self.characterForm.rawValue, privacy: .public) punctuationForm=\(self.punctuationForm.rawValue, privacy: .public) schemaID=\(schemaID, privacy: .public) userDict=\(userDictionaryName, privacy: .public) hasEverExpanded=\(self.inputSession.hasEverExpandedInCurrentComposition, privacy: .public) isComposing=\(snapshot.isComposing, privacy: .public) hasCandidates=\(!snapshot.items.isEmpty, privacy: .public) visibleCandidates=\(visibleCandidates, privacy: .public)"
            )
        }

        private func smokePreviewState(_ state: BilingualPreviewState) -> String {
            switch state {
            case .unavailable:
                return "unavailable"
            case .loading:
                return "loading"
            case .ready:
                return "ready"
            case .failed:
                return "failed"
            }
        }

        private func smokeCandidateList(_ snapshot: BilingualCompositionSnapshot) -> String {
            snapshot.items.enumerated().map { index, item in
                let diagnostics = smokeFallbackFontResolver.diagnostics(
                    for: item.candidate.surface,
                    baseFont: smokeCandidateFont
                )
                return "\(index):\(smokeValue(item.candidate.surface)){\(diagnostics)}"
            }
            .joined(separator: "|")
        }

        private func smokeValue(_ value: String) -> String {
            value.isEmpty ? "<empty>" : value.replacingOccurrences(of: " ", with: "␠")
        }
    #endif
}
