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
        let previousCandidateIDs = visibleCandidateIDs(for: engineSnapshot)
        engineSnapshot = newSnapshot
        if rawInput != engineSnapshot.rawInput {
            rawInput = engineSnapshot.rawInput
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

    func normalize(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)

        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 65...90:
                result.unicodeScalars.append(UnicodeScalar(scalar.value + 32)!)
            case 97...122:
                result.unicodeScalars.append(scalar)
            case 39:
                result.append("'")
            default:
                continue
            }
        }

        return result
    }
}
