public struct PreviewCache: Sendable {
    private var storage: [PreviewRequestKey: String]
    private var recency: [PreviewRequestKey]
    private let capacity: Int

    public init(storage: [PreviewRequestKey: String] = [:], capacity: Int = 512) {
        self.storage = storage
        self.recency = Array(storage.keys)
        self.capacity = max(1, capacity)
        trimToCapacity()
    }

    public mutating func value(for key: PreviewRequestKey) -> String? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    public mutating func insert(_ value: String, for key: PreviewRequestKey) {
        storage[key] = value
        touch(key)
        trimToCapacity()
    }

    private mutating func touch(_ key: PreviewRequestKey) {
        recency.removeAll { $0 == key }
        recency.append(key)
    }

    private mutating func trimToCapacity() {
        while storage.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
