import BilineCore
import Foundation

extension BilingualInputSession {
    var hasValidQueryInput: Bool {
        !rawInput.isEmpty && rawInput == normalize(rawInput)
    }

    func advanceCompositionRevision() {
        compositionRevision += 1
    }

    func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        lockDepth += 1
        defer {
            lockDepth -= 1
            let snapshotToFire: BilingualCompositionSnapshot?
            if lockDepth == 0, hasPendingNotification {
                hasPendingNotification = false
                if suppressSnapshotNotification {
                    snapshotToFire = nil
                } else {
                    snapshotToFire = currentSnapshot
                }
            } else {
                snapshotToFire = nil
            }
            stateLock.unlock()
            if let snapshotToFire {
                onSnapshotUpdate?(snapshotToFire)
            }
        }
        return try body()
    }

    func updateEngineSnapshot(_ newSnapshot: CompositionSnapshot) {
        let newSnapshot = applyingLiteralLatinSuffix(to: newSnapshot)
        let previousCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        engineSnapshot = newSnapshot
        if rawInput != engineSnapshot.rawInput {
            rawInput = engineSnapshot.rawInput
            rawCursorIndex = rawInput.count
        } else {
            clampRawCursorIndex()
        }

        if engineSnapshot.candidates.isEmpty {
            compositionMode = .rawBufferOnly
            presentationMode = .compact
        } else {
            compositionMode = presentationMode == .expanded ? .candidateExpanded : .candidateCompact
        }

        let currentCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        if previousCandidateIDs != currentCandidateIDs {
            reconcilePreviews(
                previousCandidateIDs: previousCandidateIDs,
                visibleCandidates: engineSnapshot.candidates
            )
        } else {
            publishSnapshot()
        }
    }

    func applyingLiteralLatinSuffix(to snapshot: CompositionSnapshot) -> CompositionSnapshot {
        guard !literalLatinSuffix.isEmpty,
            rawInput.hasSuffix(literalLatinSuffix),
            snapshot.isComposing
        else {
            return snapshot
        }

        let queryInput = String(rawInput.dropLast(literalLatinSuffix.count))
        guard snapshot.rawInput == queryInput else {
            return snapshot
        }

        let tokenCount = pinyinSegmenter.tokenizeAll(queryInput, limit: 1).first?.count ?? 0
        let candidates = snapshot.candidates.map { candidate in
            guard tokenCount > 0, candidate.consumedTokenCount >= tokenCount else {
                return candidate
            }
            let surface = candidate.surface + literalLatinSuffix
            return Candidate(
                id: "\(candidate.id):latin:\(literalLatinSuffix)",
                surface: surface,
                reading: candidate.reading + literalLatinSuffix,
                score: candidate.score,
                consumedTokenCount: candidate.consumedTokenCount
            )
        }

        let selectedConsumesWholeQuery =
            tokenCount > 0
            && snapshot.consumedTokenCount >= tokenCount
            && snapshot.remainingRawInput.isEmpty

        return CompositionSnapshot(
            rawInput: rawInput,
            markedText: rawInput,
            candidates: candidates,
            selectedIndex: snapshot.selectedIndex,
            pageIndex: snapshot.pageIndex,
            isComposing: true,
            activeRawInput: selectedConsumesWholeQuery ? rawInput : snapshot.activeRawInput,
            remainingRawInput: selectedConsumesWholeQuery
                ? ""
                : snapshot.remainingRawInput + literalLatinSuffix,
            consumedTokenCount: snapshot.consumedTokenCount
        )
    }

    func normalize(_ string: String) -> String {
        PinyinInputSegmenter.normalizePinyin(string, keepsSpaces: false)
    }
}
