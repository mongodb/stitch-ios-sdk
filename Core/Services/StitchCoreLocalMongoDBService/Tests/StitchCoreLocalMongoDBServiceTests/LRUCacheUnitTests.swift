import Foundation
import XCTest
@testable import StitchCoreLocalMongoDBService

class LRUCacheUnitTests: XCTestCase {
    func testLRUCache() {
        let lruCache = LRUCache<String, Int>(capacity: 3)

        lruCache["one"] = 1
        XCTAssertEqual(lruCache.count, 1)

        lruCache["two"] = 2
        XCTAssertEqual(lruCache.count, 2)

        lruCache["three"] = 3
        XCTAssertEqual(lruCache.count, 3)

        lruCache["four"] = 4
        XCTAssertEqual(lruCache.count, 3)

        // three will have gotten booted since it's
        // the least used
        XCTAssertNotNil(lruCache["four"])
        XCTAssertNotNil(lruCache["two"])
        XCTAssertNotNil(lruCache["one"])

        // up the usage count
        _ = lruCache["two"]
        _ = lruCache["two"]
        _ = lruCache["one"]

        var iterator = lruCache.makeIterator()
        XCTAssertEqual(iterator.next()?.1, 2)
        XCTAssertEqual(iterator.next()?.1, 1)
        XCTAssertEqual(iterator.next()?.1, 4)

        lruCache["three"] = 3

        XCTAssertNil(lruCache["four"])
        XCTAssertNotNil(lruCache["three"])
        XCTAssertNotNil(lruCache["two"])
        XCTAssertNotNil(lruCache["one"])

        lruCache.removeAll()

        XCTAssertEqual(lruCache.count, 0)
    }
}
