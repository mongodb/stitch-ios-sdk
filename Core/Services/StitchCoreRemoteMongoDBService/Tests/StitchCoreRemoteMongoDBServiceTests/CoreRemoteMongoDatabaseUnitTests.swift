import XCTest
import Foundation
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

final class CoreRemoteMongoDatabaseUnitTests: XCTestCase {
    func testGetName() {
        let db1 = TestUtils.getDatabase()
        XCTAssertEqual("dbName1", db1.name)

        let db2 = TestUtils.getDatabase(withName: "dbName2")
        XCTAssertEqual("dbName2", db2.name)
    }

    func testGetCollection() {
        let db1 = TestUtils.getDatabase()
        let coll1 = db1.collection("collName1")
        XCTAssertEqual("collName1", coll1.name)
        XCTAssertEqual("dbName1", coll1.databaseName)

        let coll2 = db1.collection("collName2")
        XCTAssertEqual("collName2", coll2.name)
        XCTAssertEqual("dbName1", coll2.databaseName)
        XCTAssertTrue(type(of: coll2).CollectionType.self == Document.self)

        let coll3 = db1.collection("collName3", withCollectionType: Int.self)
        XCTAssertTrue(type(of: coll3).CollectionType.self == Int.self)
    }
}
