import MongoSwift
import StitchCoreSDK
import Foundation

internal final class LRUCache<Key: Hashable, Value>: Sequence {
    fileprivate struct Payload: Comparable, Hashable {
        static func < (lhs: LRUCache<Key, Value>.Payload, rhs: LRUCache<Key, Value>.Payload) -> Bool {
            return lhs.used > rhs.used
        }

        static func == (lhs: LRUCache<Key, Value>.Payload, rhs: LRUCache<Key, Value>.Payload) -> Bool {
            return lhs.key == rhs.key
        }

        let key: Key
        let value: Value
        var used: Int

        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }

    typealias Element = (Key, Value)
    typealias Iterator = LRUCacheIterator
    private var list = [Payload]()
    private let capacity: UInt
    private let lock = ReadWriteLock.init(label: "lru_\(ObjectId().hex)")

    struct LRUCacheIterator: IteratorProtocol {
        // Since this is only going to be a temporary class (will go away when Swift driver is thread-safe),
        // we can make this linter exception.
        // swiftlint:disable nesting
        typealias Element = LRUCache.Element
        // swiftlint:enable nesting
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

            let payload = values[index]
            return (payload.key, payload.value)
        }
    }

    init(capacity: UInt) {
        self.capacity = capacity
    }

    subscript(_ key: Key) -> Value? {
        get {
            return lock.write { [weak self] in
                guard let index = self?.list.firstIndex(where: { (payload) -> Bool in
                    payload.key == key
                }) else {
                    return nil
                }

                self?.list[index].used += 1
                let value = list[index]
                self?.list.sort()
                return value.value
            }
        }
        set {
            lock.write {
                guard let value = newValue else {
                    guard let index = list.firstIndex(where: { payload -> Bool in payload.key == key }) else {
                        return
                    }
                    list.remove(at: index)
                    return
                }

                if list.count >= capacity {
                    list.removeLast()
                }

                list.append(Payload(key: key, value: value, used: 0))
            }
        }
    }

    func removeAll() {
        lock.write {
            list.removeAll()
        }
    }

    func makeIterator() -> LRUCache<Key, Value>.LRUCacheIterator {
        return lock.read {
            return LRUCacheIterator(self.list)
        }
    }

    var count: Int {
        return lock.read {
            return self.list.count
        }
    }
}
