import BilineHost
import BilineSession
import Cocoa
@preconcurrency import InputMethodKit
import OSLog

final class BilineTextInputBridge: @unchecked Sendable {
    private enum AnchorTrustResult {
        case valid(CandidateAnchorRect)
        case invalid(String)
    }

    private struct ResolvedAnchorResult {
        let rect: NSRect?
        let source: String
        let rejectionReason: String?
        let rawRect: NSRect
        let retriedRect: NSRect?
        let fallbackRect: NSRect?
        let queriedIndex: Int?
        let markedRange: NSRange?
        let selectedRange: NSRange?
        let actualRange: NSRange?
    }

    private struct AnchorProbeResult {
        let rect: NSRect
        let source: String
        let rejectionReason: String?
        let queriedIndex: Int?
        let actualRange: NSRange?
    }

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
    private var anchorRetryKey: String?
    private var anchorRetryAttemptCount = 0
    private var pendingAnchorRetry: DispatchWorkItem?

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
                candidatePanel.hide(reason: "snapshot-not-composing")
                return
            }

            let anchorResult = resolveAnchorRect(for: client, snapshot: snapshot)
            guard let anchorRect = anchorResult.rect else {
                #if DEBUG
                    BilineHostSmokeReporter.shared.record(
                        .anchorRejected,
                        fields: anchorTelemetryFields(anchorResult)
                    )
                #endif
                if !didLogMissingAnchor {
                    didLogMissingAnchor = true
                    logger.info("Candidate panel hidden because anchor rect could not be resolved")
                }
                candidatePanel.hide(
                    reason: "anchor-unresolved:\(anchorResult.rejectionReason ?? "unknown")")
                scheduleAnchorRetry(
                    snapshot: snapshot,
                    client: client,
                    candidatePanel: candidatePanel,
                    reason: anchorResult.rejectionReason ?? "unknown"
                )
                return
            }

            clearAnchorRetry()
            #if DEBUG
                BilineHostSmokeReporter.shared.record(
                    .anchorResolved,
                    fields: anchorTelemetryFields(anchorResult, resolvedRect: anchorRect)
                )
            #endif

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
            clearAnchorRetry()
            lastWindowLevelClientID = nil
            lastWindowLevelRawValue = nil
        }
    }

    func clearComposition(in client: IMKTextInput) {
        MainThreadExecutor.sync {
            clearCompositionOnMainThread(in: client)
        }
    }

    func hide(candidatePanel: BilineCandidatePanelController, reason: String = "bridge-hide") {
        MainThreadExecutor.sync {
            candidatePanel.hide(reason: reason)
        }
    }

    @MainActor
    private func clearCompositionOnMainThread(in client: IMKTextInput) {
        didLogFirstPanelShow = false
        didLogMissingAnchor = false
        invalidateMarkedCacheOnMainThread()
        clearAnchorRetry()
        #if DEBUG
            BilineHostSmokeReporter.shared.record(
                .compositionCleared,
                fields: [
                    "clientID": clientIdentifier(for: client)
                ]
            )
        #endif
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
        let attributedMarkedText = attributedMarkedText(for: snapshot)
        let selection = snapshot.markedSelectionRange

        if lastMarkedClientID == clientID,
            lastMarkedText == markedText,
            let cachedSelection = lastMarkedSelection,
            NSEqualRanges(cachedSelection, selection)
        {
            return
        }

        client.setMarkedText(
            attributedMarkedText,
            selectionRange: selection,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        #if DEBUG
            BilineHostSmokeReporter.shared.record(
                .markedTextApplied,
                fields: [
                    "clientID": clientID,
                    "markedText": markedText,
                    "selectionLocation": String(selection.location),
                    "selectionLength": String(selection.length),
                ]
            )
        #endif
        lastMarkedClientID = clientID
        lastMarkedText = markedText
        lastMarkedSelection = selection
        resetAnchorRetryIfNeeded(for: anchorRetryKey(snapshot: snapshot, clientID: clientID))
    }

    @MainActor
    private func attributedMarkedText(
        for snapshot: BilingualCompositionSnapshot
    ) -> NSAttributedString {
        let text = snapshot.markedText
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: NSColor.controlAccentColor.withAlphaComponent(0.72),
                .markedClauseSegment: 0,
            ]
        )
        return attributed
    }

    @MainActor
    private func invalidateMarkedCacheOnMainThread() {
        lastMarkedClientID = nil
        lastMarkedText = nil
        lastMarkedSelection = nil
    }

    @MainActor
    private func scheduleAnchorRetry(
        snapshot: BilingualCompositionSnapshot,
        client: IMKTextInput,
        candidatePanel: BilineCandidatePanelController,
        reason: String
    ) {
        guard snapshot.isComposing else { return }
        guard reason == "zero-size" || reason == "origin-zero" || reason == "offscreen" else {
            return
        }

        let key = anchorRetryKey(snapshot: snapshot, clientID: clientIdentifier(for: client))
        resetAnchorRetryIfNeeded(for: key)
        guard anchorRetryAttemptCount < 6, pendingAnchorRetry == nil else { return }

        anchorRetryAttemptCount += 1
        let clientObject = client as AnyObject
        let delay = DispatchTimeInterval.milliseconds(50 * anchorRetryAttemptCount)
        let workItem = DispatchWorkItem { [weak self, weak clientObject, weak candidatePanel] in
            guard let self,
                let client = clientObject as? IMKTextInput,
                let candidatePanel
            else {
                return
            }
            MainThreadExecutor.sync {
                guard self.anchorRetryKey == key else { return }
                self.pendingAnchorRetry = nil
                self.render(snapshot: snapshot, client: client, candidatePanel: candidatePanel)
            }
        }
        pendingAnchorRetry = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @MainActor
    private func resetAnchorRetryIfNeeded(for key: String) {
        guard anchorRetryKey != key else { return }
        pendingAnchorRetry?.cancel()
        pendingAnchorRetry = nil
        anchorRetryKey = key
        anchorRetryAttemptCount = 0
    }

    @MainActor
    private func clearAnchorRetry() {
        pendingAnchorRetry?.cancel()
        pendingAnchorRetry = nil
        anchorRetryKey = nil
        anchorRetryAttemptCount = 0
    }

    @MainActor
    private func anchorRetryKey(snapshot: BilingualCompositionSnapshot, clientID: String) -> String
    {
        [
            clientID,
            String(snapshot.revision),
            snapshot.rawInput,
            snapshot.markedText,
            snapshot.presentationMode.rawValue,
            String(snapshot.pageIndex),
            String(snapshot.selectedRow),
            String(snapshot.selectedColumn),
            snapshot.activeLayer.rawValue,
            String(snapshot.markedSelectionRange.location),
            String(snapshot.markedSelectionRange.length),
        ].joined(separator: "|")
    }

    @MainActor
    private func resolveAnchorRect(
        for client: IMKTextInput,
        snapshot: BilingualCompositionSnapshot
    ) -> ResolvedAnchorResult {
        let markedRange = client.markedRange()
        let selectedRange = client.selectedRange()
        let anchorIndex = max(0, snapshot.markedSelectionRange.location - 1)
        let primary = resolveAnchorUsingAttributes(
            for: client,
            anchorIndex: anchorIndex,
            sourceAfterInvalidation: false
        )
        let context = CandidateAnchorContext(clientID: clientIdentifier(for: client))
        if primary.rejectionReason == nil {
            let currentRect = CandidateAnchorRect(primary.rect)
            let resolved = anchorTracker.resolve(currentRect: currentRect, context: context)
            return ResolvedAnchorResult(
                rect: resolved?.nsRect,
                source: primary.source,
                rejectionReason: nil,
                rawRect: primary.rect,
                retriedRect: nil,
                fallbackRect: nil,
                queriedIndex: primary.queriedIndex,
                markedRange: markedRange,
                selectedRange: selectedRange,
                actualRange: nil
            )
        }

        NSTextInputContext.current?.invalidateCharacterCoordinates()
        let retried = resolveAnchorUsingAttributes(
            for: client,
            anchorIndex: anchorIndex,
            sourceAfterInvalidation: true
        )
        if retried.rejectionReason == nil {
            let currentRect = CandidateAnchorRect(retried.rect)
            let resolved = anchorTracker.resolve(currentRect: currentRect, context: context)
            return ResolvedAnchorResult(
                rect: resolved?.nsRect,
                source: retried.source,
                rejectionReason: primary.rejectionReason,
                rawRect: primary.rect,
                retriedRect: retried.rect,
                fallbackRect: nil,
                queriedIndex: retried.queriedIndex,
                markedRange: markedRange,
                selectedRange: selectedRange,
                actualRange: nil
            )
        }

        let firstRect = resolveFirstRect(
            for: client, markedRange: markedRange, selectedRange: selectedRange)
        if firstRect.rejectionReason == nil {
            let currentRect = CandidateAnchorRect(firstRect.rect)
            let resolved = anchorTracker.resolve(currentRect: currentRect, context: context)
            return ResolvedAnchorResult(
                rect: resolved?.nsRect,
                source: firstRect.source,
                rejectionReason: primary.rejectionReason,
                rawRect: primary.rect,
                retriedRect: retried.rect,
                fallbackRect: firstRect.rect,
                queriedIndex: nil,
                markedRange: markedRange,
                selectedRange: selectedRange,
                actualRange: firstRect.actualRange
            )
        }

        let resolved = anchorTracker.resolve(currentRect: nil, context: context)
        return ResolvedAnchorResult(
            rect: resolved?.nsRect,
            source: resolved == nil ? "missing" : "fallback",
            rejectionReason: firstRect.rejectionReason ?? retried.rejectionReason
                ?? primary.rejectionReason,
            rawRect: primary.rect,
            retriedRect: retried.rect,
            fallbackRect: resolved?.nsRect,
            queriedIndex: firstRect.queriedIndex ?? retried.queriedIndex ?? primary.queriedIndex,
            markedRange: markedRange,
            selectedRange: selectedRange,
            actualRange: firstRect.actualRange
        )
    }

    @MainActor
    private func resolveAnchorUsingAttributes(
        for client: IMKTextInput,
        anchorIndex: Int,
        sourceAfterInvalidation: Bool
    ) -> AnchorProbeResult {
        var latestFailure: AnchorProbeResult?
        for query in CandidateAnchorQueryPlanner.attributeQueries(
            anchorIndex: anchorIndex,
            afterInvalidation: sourceAfterInvalidation
        ) {
            var rect = NSRect.zero
            _ = client.attributes(forCharacterIndex: query.index, lineHeightRectangle: &rect)

            switch trustedAnchorRect(rect) {
            case .valid:
                return AnchorProbeResult(
                    rect: rect,
                    source: query.source,
                    rejectionReason: nil,
                    queriedIndex: query.index,
                    actualRange: nil
                )
            case .invalid(let reason):
                latestFailure = AnchorProbeResult(
                    rect: rect,
                    source: query.source,
                    rejectionReason: reason,
                    queriedIndex: query.index,
                    actualRange: nil
                )
            }
        }

        return latestFailure
            ?? AnchorProbeResult(
                rect: .zero,
                source: sourceAfterInvalidation
                    ? "attributes-after-invalidate" : "attributes-cursor",
                rejectionReason: "missing",
                queriedIndex: nil,
                actualRange: nil
            )
    }

    @MainActor
    private func resolveFirstRect(
        for client: IMKTextInput,
        markedRange: NSRange,
        selectedRange: NSRange
    ) -> AnchorProbeResult {
        let candidates: [(source: String, range: NSRange)] = [
            ("imk-first-rect-marked", markedRange),
            ("imk-first-rect-selected", selectedRange),
            ("imk-first-rect-caret", NSRange(location: NSNotFound, length: 0)),
        ]
        var latestFailure: AnchorProbeResult?

        for candidate in candidates {
            guard candidate.range.length != NSNotFound else { continue }
            var actualRange = NSRange(location: NSNotFound, length: 0)
            let rect = client.firstRect(
                forCharacterRange: candidate.range, actualRange: &actualRange)
            switch trustedAnchorRect(rect) {
            case .valid:
                return AnchorProbeResult(
                    rect: rect,
                    source: candidate.source,
                    rejectionReason: nil,
                    queriedIndex: nil,
                    actualRange: actualRange
                )
            case .invalid(let reason):
                latestFailure = AnchorProbeResult(
                    rect: rect,
                    source: candidate.source,
                    rejectionReason: reason,
                    queriedIndex: nil,
                    actualRange: actualRange
                )
            }
        }

        return latestFailure
            ?? AnchorProbeResult(
                rect: .zero,
                source: "imk-first-rect-caret",
                rejectionReason: "missing",
                queriedIndex: nil,
                actualRange: nil
            )
    }

    @MainActor
    private func trustedAnchorRect(_ rect: NSRect) -> AnchorTrustResult {
        // Reject obviously degenerate rects that some hosts return while
        // their text storage is still settling: NaN/infinite components,
        // zero-by-zero rects, and rects pinned to the screen origin
        // `(0, 0, *, *)` which are a known sentinel for "I don't know yet".
        guard rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.size.width.isFinite,
            rect.size.height.isFinite
        else {
            return .invalid("non-finite")
        }

        if rect.size.width <= 0 && rect.size.height <= 0 {
            return .invalid("zero-size")
        }

        if rect.origin.x == 0 && rect.origin.y == 0 {
            return .invalid("origin-zero")
        }

        guard NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            return .invalid("offscreen")
        }

        return .valid(CandidateAnchorRect(rect))
    }

    @MainActor
    private func anchorTelemetryFields(
        _ result: ResolvedAnchorResult,
        resolvedRect: NSRect? = nil
    ) -> [String: String?] {
        var fields: [String: String?] = [
            "reason": result.rejectionReason,
            "source": result.source,
            "queriedIndex": result.queriedIndex.map(String.init),
            "rawX": String(describing: result.rawRect.origin.x),
            "rawY": String(describing: result.rawRect.origin.y),
            "rawWidth": String(describing: result.rawRect.size.width),
            "rawHeight": String(describing: result.rawRect.size.height),
            "retriedX": result.retriedRect.map { String(describing: $0.origin.x) },
            "retriedY": result.retriedRect.map { String(describing: $0.origin.y) },
            "retriedWidth": result.retriedRect.map { String(describing: $0.size.width) },
            "retriedHeight": result.retriedRect.map { String(describing: $0.size.height) },
            "fallbackX": result.fallbackRect.map { String(describing: $0.origin.x) },
            "fallbackY": result.fallbackRect.map { String(describing: $0.origin.y) },
            "fallbackWidth": result.fallbackRect.map { String(describing: $0.size.width) },
            "fallbackHeight": result.fallbackRect.map { String(describing: $0.size.height) },
            "resolvedX": resolvedRect.map { String(describing: $0.origin.x) },
            "resolvedY": resolvedRect.map { String(describing: $0.origin.y) },
            "resolvedWidth": resolvedRect.map { String(describing: $0.size.width) },
            "resolvedHeight": resolvedRect.map { String(describing: $0.size.height) },
        ]
        appendRangeFields(prefix: "markedRange", range: result.markedRange, to: &fields)
        appendRangeFields(prefix: "selectedRange", range: result.selectedRange, to: &fields)
        appendRangeFields(prefix: "actualRange", range: result.actualRange, to: &fields)
        return fields
    }

    @MainActor
    private func appendRangeFields(
        prefix: String,
        range: NSRange?,
        to fields: inout [String: String?]
    ) {
        fields["\(prefix)Location"] = range.map { String($0.location) }
        fields["\(prefix)Length"] = range.map { String($0.length) }
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
