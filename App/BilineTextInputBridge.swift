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

            guard let anchorRect = resolveAnchorRect(for: client, snapshot: snapshot) else {
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
        }
    }

    func clearAnchorCache() {
        MainThreadExecutor.sync {
            anchorTracker.clear()
            didLogFirstPanelShow = false
            didLogMissingAnchor = false
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
        client.setMarkedText(
            snapshot.markedText,
            selectionRange: snapshot.markedSelectionRange,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    @MainActor
    private func resolveAnchorRect(
        for client: IMKTextInput,
        snapshot: BilingualCompositionSnapshot
    ) -> NSRect? {
        var lineHeightRect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineHeightRect)

        let currentRect = trustedAnchorRect(lineHeightRect)
        let context = CandidateAnchorContext(
            clientID: String(ObjectIdentifier(client as AnyObject).hashValue),
            revision: snapshot.revision
        )
        let resolved = anchorTracker.resolve(currentRect: currentRect, context: context)
        return resolved?.nsRect
    }

    @MainActor
    private func trustedAnchorRect(_ rect: NSRect) -> CandidateAnchorRect? {
        let anchorRect = CandidateAnchorRect(rect)
        guard anchorRect.isValid else { return nil }
        let probeRect = NSRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.width, 1),
            height: max(rect.height, 1)
        )
        guard NSScreen.screens.contains(where: { $0.frame.intersects(probeRect) }) else {
            return nil
        }
        return anchorRect
    }

    @MainActor
    private func candidateWindowLevel(for client: IMKTextInput) -> NSWindow.Level {
        NSWindow.Level(rawValue: Int(client.windowLevel() + 1))
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
