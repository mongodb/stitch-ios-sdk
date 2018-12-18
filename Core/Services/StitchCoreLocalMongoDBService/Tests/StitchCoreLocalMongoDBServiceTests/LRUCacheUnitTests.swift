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

        XCTAssertNotNil(lruCache["four"])
        XCTAssertNotNil(lruCache["three"])
        XCTAssertNotNil(lruCache["two"])
        XCTAssertNil(lruCache["one"])

        // up the usage count
        _ = lruCache["three"]
        _ = lruCache["two"]

        var iterator = lruCache.makeIterator()
        XCTAssertEqual(iterator.next()?.1, 3)
        XCTAssertEqual(iterator.next()?.1, 2)
        XCTAssertEqual(iterator.next()?.1, 4)

        lruCache["one"] = 1

        XCTAssertNil(lruCache["four"])
        XCTAssertNotNil(lruCache["three"])
        XCTAssertNotNil(lruCache["two"])
        XCTAssertNotNil(lruCache["one"])

        lruCache.removeAll()

        XCTAssertEqual(lruCache.count, 0)
    }
}
