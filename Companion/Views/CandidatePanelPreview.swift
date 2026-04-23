import AppKit
import BilineCore
import BilinePanelUI
import BilineSession
import BilineSettings
import SwiftUI

struct CandidatePanelPreview: View {
    let themeMode: PanelThemeMode
    let fontScale: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            CandidatePanelPreviewRepresentable(
                snapshot: Self.snapshot,
                theme: PanelTheme(mode: themeMode, fontScale: fontScale)
            )
            .frame(maxWidth: .infinity, minHeight: previewHeight)
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: previewHeight + 32)
    }

    private var previewHeight: CGFloat {
        CGFloat(84 * max(1.0, fontScale))
    }
}

private struct CandidatePanelPreviewRepresentable: NSViewRepresentable {
    let snapshot: BilingualCompositionSnapshot
    let theme: PanelTheme

    func makeNSView(context: Context) -> CandidatePanelPreviewHostView {
        let view = CandidatePanelPreviewHostView()
        view.update(snapshot: snapshot, theme: theme)
        return view
    }

    func updateNSView(_ nsView: CandidatePanelPreviewHostView, context: Context) {
        nsView.update(snapshot: snapshot, theme: theme)
    }
}

extension CandidatePanelPreview {
    private static let snapshot = BilingualCompositionSnapshot(
        rawInput: "xizhilang",
        remainingRawInput: "",
        displayRawInput: "xizhilang",
        markedText: "xizhilang",
        rawCursorIndex: 9,
        markedSelectionLocation: 9,
        items: [
            BilingualCandidateItem(
                candidate: Candidate(
                    id: "preview-xizhilang",
                    surface: "曦之郎",
                    reading: "xizhilang",
                    score: 100,
                    consumedTokenCount: 3
                ),
                previewState: .ready("Xizhi Huang")
            ),
        ],
        showsEnglishCandidates: true,
        pageIndex: 0,
        activeLayer: .chinese,
        presentationMode: .compact,
        selectedRow: 0,
        selectedColumn: 0,
        compactColumnCount: 5,
        expandedRowCount: 5,
        isComposing: true
    )
}

private final class CandidatePanelPreviewHostView: NSView {
    private let panelView = BilineCandidatePanelView(frame: .zero)

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(panelView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(panelView)
    }

    func update(snapshot: BilingualCompositionSnapshot, theme: PanelTheme) {
        if panelView.snapshot != snapshot {
            panelView.snapshot = snapshot
        }
        panelView.applyTheme(theme)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let size = panelView.preferredSize
        panelView.frame = NSRect(
            x: max(0, (bounds.width - size.width) / 2),
            y: max(0, (bounds.height - size.height) / 2),
            width: size.width,
            height: size.height
        )
    }
}
