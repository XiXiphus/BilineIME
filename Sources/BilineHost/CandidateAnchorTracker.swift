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
