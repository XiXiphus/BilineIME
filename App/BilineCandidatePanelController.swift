import BilinePanelUI
import BilineSession
import Cocoa

@MainActor
final class BilineCandidatePanelController: @unchecked Sendable {
    private let panel: CandidatePanelWindow
    private let contentView: BilineCandidatePanelView
    private let layout = CandidatePanelLayout()
    private var isVisible = false
    private var lastFrame = NSRect.zero
    private var lastSnapshot: BilingualCompositionSnapshot?
    private var lastWindowLevelRawValue: Int?

    init() {
        self.contentView = BilineCandidatePanelView(frame: .zero)
        self.panel = CandidatePanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
    }

    func render(
        snapshot: BilingualCompositionSnapshot,
        anchorRect: NSRect,
        windowLevel: NSWindow.Level
    ) {
        guard snapshot.isComposing, !snapshot.rawInput.isEmpty else {
            hide(reason: "snapshot-not-composing-or-empty")
            return
        }

        #if DEBUG
            BilineHostSmokeReporter.shared.record(
                .panelRenderRequested,
                fields: [
                    "rawInput": snapshot.rawInput,
                    "candidateCount": String(snapshot.items.count),
                    "anchorX": String(describing: anchorRect.origin.x),
                    "anchorY": String(describing: anchorRect.origin.y),
                    "anchorWidth": String(describing: anchorRect.size.width),
                    "anchorHeight": String(describing: anchorRect.size.height),
                    "windowLevel": String(windowLevel.rawValue),
                ]
            )
        #endif
        let previousSnapshot = lastSnapshot
        if contentView.snapshot != snapshot {
            contentView.snapshot = snapshot
        }
        let panelSize = contentView.preferredSize
        let panelFrame = layout.positionedFrame(size: panelSize, anchorRect: anchorRect)
        if lastWindowLevelRawValue != windowLevel.rawValue {
            panel.level = windowLevel
            lastWindowLevelRawValue = windowLevel.rawValue
        }
        if panelFrame != lastFrame {
            setPanelFrame(
                panelFrame,
                animated: shouldAnimateFrameTransition(
                    from: lastFrame,
                    to: panelFrame,
                    previousSnapshot: previousSnapshot,
                    currentSnapshot: snapshot
                )
            )
            lastFrame = panelFrame
        }
        lastSnapshot = snapshot
        if !isVisible {
            panel.orderFrontRegardless()
            isVisible = true
            #if DEBUG
                BilineHostSmokeReporter.shared.record(
                    .panelShown,
                    fields: [
                        "frameX": String(describing: panelFrame.origin.x),
                        "frameY": String(describing: panelFrame.origin.y),
                        "frameWidth": String(describing: panelFrame.size.width),
                        "frameHeight": String(describing: panelFrame.size.height),
                        "candidateCount": String(snapshot.items.count),
                        "rawInput": snapshot.rawInput,
                    ]
                )
            #endif
        } else {
            #if DEBUG
                BilineHostSmokeReporter.shared.record(
                    .panelUpdated,
                    fields: [
                        "frameX": String(describing: panelFrame.origin.x),
                        "frameY": String(describing: panelFrame.origin.y),
                        "frameWidth": String(describing: panelFrame.size.width),
                        "frameHeight": String(describing: panelFrame.size.height),
                        "candidateCount": String(snapshot.items.count),
                        "rawInput": snapshot.rawInput,
                    ]
                )
            #endif
        }
    }

    func hide(reason: String = "unspecified") {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        lastFrame = .zero
        lastSnapshot = nil
        lastWindowLevelRawValue = nil
        #if DEBUG
            BilineHostSmokeReporter.shared.record(
                .panelHidden,
                fields: [
                    "reason": reason
                ]
            )
        #endif
    }

    private func setPanelFrame(_ frame: NSRect, animated: Bool) {
        guard animated else {
            panel.setFrame(frame, display: true)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func shouldAnimateFrameTransition(
        from oldFrame: NSRect,
        to newFrame: NSRect,
        previousSnapshot: BilingualCompositionSnapshot?,
        currentSnapshot: BilingualCompositionSnapshot
    ) -> Bool {
        guard isVisible, let previousSnapshot else { return false }
        guard previousSnapshot.rawInput == currentSnapshot.rawInput else { return false }
        guard !previousSnapshot.items.isEmpty, !currentSnapshot.items.isEmpty else { return false }
        guard previousSnapshot.presentationMode != currentSnapshot.presentationMode else {
            return false
        }

        return abs(oldFrame.height - newFrame.height) > 0.5
    }

    /// Applies a new theme to the contained view. Layout-affecting changes
    /// (font scale) invalidate the panel's intrinsic size cache; visual-only
    /// changes (mode) just trigger a redraw. Safe to call from any thread;
    /// hops to main internally.
    ///
    /// When the panel is currently visible we also resize and re-show it so
    /// font-scale changes take effect immediately without waiting for the
    /// next keystroke. The anchor stays where it last was (we deliberately
    /// don't requery the host) because the host may not have a marked-text
    /// anchor available at this moment.
    nonisolated func applyTheme(_ theme: PanelTheme) {
        MainThreadExecutor.sync {
            self.contentView.applyTheme(theme)
            guard self.isVisible else { return }
            let newSize = self.contentView.preferredSize
            let origin = self.lastFrame.origin
            let newFrame = NSRect(origin: origin, size: newSize)
            if newFrame != self.lastFrame {
                self.panel.setFrame(newFrame, display: true)
                self.lastFrame = newFrame
            }
        }
    }
}
