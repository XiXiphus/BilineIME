import Foundation

enum MainThreadExecutor {
    static func sync<T: Sendable>(_ body: @MainActor () throws -> T) rethrows -> T {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated(body)
        }

        return try DispatchQueue.main.sync {
            try MainActor.assumeIsolated(body)
        }
    }
}
