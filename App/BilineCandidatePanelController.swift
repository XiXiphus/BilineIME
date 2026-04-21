import BilineSession
import Cocoa

@MainActor
final class BilineCandidatePanelController: @unchecked Sendable {
    private let panel: CandidatePanelWindow
    private let contentView: BilineCandidatePanelView
    private let layout = CandidatePanelLayout()

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

        contentView.snapshot = snapshot
        let panelSize = contentView.preferredSize
        let panelFrame = layout.positionedFrame(size: panelSize, anchorRect: anchorRect)
        panel.level = windowLevel
        panel.setFrame(panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
