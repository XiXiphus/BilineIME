import Foundation

public struct CandidateAnchorRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && (width > 0 || height > 0)
    }
}

/// Identifies the input client whose caret rect we are tracking.
///
/// The cache is intentionally keyed only by `clientID` so that a momentary
/// invalid rect from the host (which happens often around marked-text resets,
/// IMK XPC races, or background-thread queries) can fall back to the most
/// recent good rect for the same client. Apple's IMK guidance is that hosts
/// may temporarily return a zero/garbage rect for `attributesForCharacterIndex:lineHeightRectangle:`
/// while their layout settles; we should remember the last known good rect
/// for the lifetime of the client and only invalidate it when the client
/// changes (or `clear()` is called explicitly on commit/cancel/deactivate).
public struct CandidateAnchorContext: Sendable, Equatable {
    public let clientID: String

    public init(clientID: String) {
        self.clientID = clientID
    }
}

public final class CandidateAnchorTracker: @unchecked Sendable {
    private var lastValidRect: CandidateAnchorRect?
    private var lastContext: CandidateAnchorContext?

    public init() {}

    public func resolve(
        currentRect: CandidateAnchorRect?,
        context: CandidateAnchorContext
    ) -> CandidateAnchorRect? {
        if lastContext != context {
            lastValidRect = nil
            lastContext = context
        }
        if let currentRect, currentRect.isValid {
            lastValidRect = currentRect
            return currentRect
        }
        return lastValidRect
    }

    public func clear() {
        lastValidRect = nil
        lastContext = nil
    }
}

public struct CandidateAnchorAttributeQuery: Sendable, Equatable {
    public let index: Int
    public let source: String

    public init(index: Int, source: String) {
        self.index = max(0, index)
        self.source = source
    }
}

public enum CandidateAnchorQueryPlanner {
    public static func attributeQueries(
        anchorIndex: Int,
        afterInvalidation: Bool = false
    ) -> [CandidateAnchorAttributeQuery] {
        let anchorIndex = max(0, anchorIndex)
        var indices = [anchorIndex]
        if anchorIndex > 1 {
            indices.append(contentsOf: stride(from: anchorIndex - 1, through: 1, by: -1))
        }
        if anchorIndex != 0 {
            indices.append(0)
        }

        return indices.enumerated().map { offset, index in
            let source: String
            if afterInvalidation {
                source = "attributes-after-invalidate"
            } else if offset == 0 {
                source = "attributes-cursor"
            } else if index == 0 {
                source = "attributes-zero"
            } else {
                source = "attributes-scan"
            }
            return CandidateAnchorAttributeQuery(index: index, source: source)
        }
    }
}
