import BilineHost
import BilineSession
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

final class BilineTextInputBridge: @unchecked Sendable {
    private let anchorTracker = CandidateAnchorTracker()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.xixiphus.inputmethod.BilineIME",
        category: "bridge"
    )
    private var didLogFirstPanelShow = false
    private var didLogMissingAnchor = false

    /// Most recently sent marked-text payload, scoped per client. We use this
    /// to suppress redundant `setMarkedText:` calls on every keystroke. IMK
    /// hosts treat `setMarkedText` as a layout-affecting mutation; rewriting
    /// the same value forces the host to reflow its text storage, query
    /// attribute caches, and (in some hosts) move the caret. Apple's IMK
    /// guidance is to only send marked text when it actually changes.
    private var lastMarkedClientID: String?
    private var lastMarkedText: String?
    private var lastMarkedSelection: NSRange?
    private var lastWindowLevelClientID: String?
    private var lastWindowLevelRawValue: Int?

    func render(
        snapshot: BilingualCompositionSnapshot,
        client: IMKTextInput,
        candidatePanel: BilineCandidatePanelController
    ) {
        MainThreadExecutor.sync {
            if snapshot.isComposing {
                applyMarkedText(snapshot: snapshot, client: client)
            } else {
                clearCompositionOnMainThread(in: client)
                candidatePanel.hide()
                return
            }

            guard let anchorRect = resolveAnchorRect(for: client) else {
                if !didLogMissingAnchor {
                    didLogMissingAnchor = true
                    logger.info("Candidate panel hidden because anchor rect could not be resolved")
                }
                candidatePanel.hide()
                return
            }

            if !didLogFirstPanelShow {
                didLogFirstPanelShow = true
                didLogMissingAnchor = false
                logger.info(
                    "Candidate panel rendering anchorX=\(anchorRect.origin.x, privacy: .public) anchorY=\(anchorRect.origin.y, privacy: .public) itemCount=\(snapshot.items.count)"
                )
            }
            candidatePanel.render(
                snapshot: snapshot,
                anchorRect: anchorRect,
                windowLevel: candidateWindowLevel(for: client)
            )
        }
    }

    func insertCommittedText(_ text: String, into client: IMKTextInput) {
        MainThreadExecutor.sync {
            client.insertText(
                text,
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            // Inserting committed text moves the caret in the host. Drop the
            // cached marked-text snapshot so the next composing keystroke is
            // sent through and the panel re-anchors against the new caret.
            invalidateMarkedCacheOnMainThread()
        }
    }

    func clearAnchorCache() {
        MainThreadExecutor.sync {
            anchorTracker.clear()
            didLogFirstPanelShow = false
            didLogMissingAnchor = false
            invalidateMarkedCacheOnMainThread()
            lastWindowLevelClientID = nil
            lastWindowLevelRawValue = nil
        }
    }

    func clearComposition(in client: IMKTextInput) {
        MainThreadExecutor.sync {
            clearCompositionOnMainThread(in: client)
        }
    }

    func hide(candidatePanel: BilineCandidatePanelController) {
        MainThreadExecutor.sync {
            candidatePanel.hide()
        }
    }

    @MainActor
    private func clearCompositionOnMainThread(in client: IMKTextInput) {
        didLogFirstPanelShow = false
        didLogMissingAnchor = false
        invalidateMarkedCacheOnMainThread()
        if let textClient = client as? NSTextInputClient {
            textClient.unmarkText()
            return
        }

        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    @MainActor
    private func applyMarkedText(
        snapshot: BilingualCompositionSnapshot,
        client: IMKTextInput
    ) {
        let clientID = clientIdentifier(for: client)
        let markedText = snapshot.markedText
        let selection = snapshot.markedSelectionRange

        if lastMarkedClientID == clientID,
            lastMarkedText == markedText,
            let cachedSelection = lastMarkedSelection,
            NSEqualRanges(cachedSelection, selection)
        {
            return
        }

        client.setMarkedText(
            markedText,
            selectionRange: selection,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        lastMarkedClientID = clientID
        lastMarkedText = markedText
        lastMarkedSelection = selection
    }

    @MainActor
    private func invalidateMarkedCacheOnMainThread() {
        lastMarkedClientID = nil
        lastMarkedText = nil
        lastMarkedSelection = nil
    }

    @MainActor
    private func resolveAnchorRect(for client: IMKTextInput) -> NSRect? {
        // IMK hosts expect `NSNotFound` to mean "give me the rect at the
        // insertion point/end of the marked range". Passing `0` queries the
        // attributes for the literal first character of the document, which
        // many hosts (TextEdit, Safari, Notes, Xcode) either return as the
        // top-left of the text view or refuse outright. Apple's
        // `IMKTextInput`/`NSTextInputClient` documentation explicitly calls
        // out `NSNotFound` for the caret/marked-range case.
        var lineHeightRect = NSRect.zero
        _ = client.attributes(
            forCharacterIndex: NSNotFound,
            lineHeightRectangle: &lineHeightRect
        )

        let currentRect = trustedAnchorRect(lineHeightRect)
        let context = CandidateAnchorContext(clientID: clientIdentifier(for: client))
        let resolved = anchorTracker.resolve(currentRect: currentRect, context: context)
        return resolved?.nsRect
    }

    @MainActor
    private func trustedAnchorRect(_ rect: NSRect) -> CandidateAnchorRect? {
        // Reject obviously degenerate rects that some hosts return while
        // their text storage is still settling: NaN/infinite components,
        // zero-by-zero rects, and rects pinned to the screen origin
        // `(0, 0, *, *)` which are a known sentinel for "I don't know yet".
        guard rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.size.width.isFinite,
            rect.size.height.isFinite
        else {
            return nil
        }

        if rect.size.width <= 0 && rect.size.height <= 0 {
            return nil
        }

        if rect.origin.x == 0 && rect.origin.y == 0 {
            return nil
        }

        guard NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            return nil
        }

        return CandidateAnchorRect(rect)
    }

    @MainActor
    private func candidateWindowLevel(for client: IMKTextInput) -> NSWindow.Level {
        let clientID = clientIdentifier(for: client)
        if lastWindowLevelClientID == clientID, let cached = lastWindowLevelRawValue {
            return NSWindow.Level(rawValue: cached)
        }
        let level = NSWindow.Level(rawValue: Int(client.windowLevel() + 1))
        lastWindowLevelClientID = clientID
        lastWindowLevelRawValue = level.rawValue
        return level
    }

    @MainActor
    private func clientIdentifier(for client: IMKTextInput) -> String {
        String(ObjectIdentifier(client as AnyObject).hashValue)
    }
}

extension CandidateAnchorRect {
    fileprivate init(_ rect: NSRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    fileprivate var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
