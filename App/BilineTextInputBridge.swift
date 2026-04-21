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
    private func resolveAnchorRect(for client: IMKTextInput) -> NSRect? {
        var lineHeightRect = NSRect.zero
        _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &lineHeightRect)

        let resolved = anchorTracker.resolve(currentRect: CandidateAnchorRect(lineHeightRect))
        return resolved?.nsRect
    }

    @MainActor
    private func candidateWindowLevel(for client: IMKTextInput) -> NSWindow.Level {
        NSWindow.Level(rawValue: Int(client.windowLevel() + 1))
    }
}

private extension CandidateAnchorRect {
    init(_ rect: NSRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    var nsRect: NSRect {
        NSRect(x: x, y: y, width: width, height: height)
    }
}
