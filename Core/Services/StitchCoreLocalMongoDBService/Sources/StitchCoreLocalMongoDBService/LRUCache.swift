internal final class LRUCache<Key: Hashable, Value>: Sequence {
    typealias Element = (Key, Value)
    typealias Iterator = LRUCacheIterator
    fileprivate typealias Payload = (Key, Value, Int)
    private var list = [Payload]()
    private let capacity: UInt

    struct LRUCacheIterator: IteratorProtocol {
        typealias Element = LRUCache.Element
        private var values: [Payload]
        private var indices: Range<Int>

        fileprivate init(_ values: [Payload]) {
            self.values = values
            self.indices = values.indices
        }

        mutating func next() -> (Key, Value)? {
            guard let index = self.indices.popFirst() else {
                return nil
            }

            let (key, value, _) = values[index]
            return (key, value)
        }
    }

    init(capacity: UInt) {
        self.capacity = capacity
    }

    subscript(_ key: Key) -> Value? {
        get {
            guard let index = list.firstIndex(where: { (payload) -> Bool in
                payload.0 == key
            }) else {
                return nil
            }

            list[index].2 += 1
            let value = list[index]
            list.sort(by: { (payload1, payload2) -> Bool in
                payload1.2 > payload2.2
            })
            return value.1
        }
        set {
            guard let value = newValue else {
                guard let index = list.firstIndex(where: { payload -> Bool in payload.0 == key }) else {
                    return
                }
                list.remove(at: index)
                return
            }

            if list.count >= capacity {
                list.removeLast()
            }

            list.insert((key, value, 0), at: 0)
        }
    }

    func removeAll() {
        list.removeAll()
    }

    func makeIterator() -> LRUCache<Key, Value>.LRUCacheIterator {
        return LRUCacheIterator(self.list)
    }

    var count: Int {
        return self.list.count
    }
}
