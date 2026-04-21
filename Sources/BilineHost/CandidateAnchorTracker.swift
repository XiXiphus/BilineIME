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

public struct CandidateAnchorContext: Sendable, Equatable {
    public let clientID: String
    public let revision: Int

    public init(clientID: String, revision: Int) {
        self.clientID = clientID
        self.revision = revision
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
        if let currentRect, currentRect.isValid {
            lastValidRect = currentRect
            lastContext = context
            return currentRect
        }
        return lastContext == context ? lastValidRect : nil
    }

    public func clear() {
        lastValidRect = nil
        lastContext = nil
    }
}
