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

public final class CandidateAnchorTracker: @unchecked Sendable {
    private var lastValidRect: CandidateAnchorRect?

    public init() {}

    public func resolve(currentRect: CandidateAnchorRect?) -> CandidateAnchorRect? {
        if let currentRect, currentRect.isValid {
            lastValidRect = currentRect
            return currentRect
        }
        return lastValidRect
    }

    public func clear() {
        lastValidRect = nil
    }
}
