import BilineSession
import Cocoa

@MainActor
final class BilineCandidatePanelController: @unchecked Sendable {
    private let panel: CandidatePanelWindow
    private let contentView: BilineCandidatePanelView
    private let layout = CandidatePanelLayout()
    private var isVisible = false
    private var lastFrame = NSRect.zero
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
            hide()
            return
        }

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
            panel.setFrame(panelFrame, display: true)
            lastFrame = panelFrame
        }
        if !isVisible {
            panel.orderFrontRegardless()
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
        lastFrame = .zero
        lastWindowLevelRawValue = nil
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
