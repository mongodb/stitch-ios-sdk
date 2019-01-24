import XCTest
import Foundation
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

final class CoreRemoteMongoDatabaseUnitTests: XCMongoMobileTestCase {
    func testGetName() throws {
        let db1 = coreRemoteMongoClient.db(namespace.databaseName)
        XCTAssertEqual(namespace.databaseName, db1.name)

        let db2 = coreRemoteMongoClient.db("dbName2")
        XCTAssertEqual("dbName2", db2.name)
    }

    func testGetCollection() throws {
        let db1 = coreRemoteMongoClient.db(namespace.databaseName)
        let coll1 = db1.collection("collName1")
        XCTAssertEqual("collName1", coll1.name)
        XCTAssertEqual(namespace.databaseName, coll1.databaseName)

        let coll2 = db1.collection("collName2")
        XCTAssertEqual("collName2", coll2.name)
        XCTAssertEqual(namespace.databaseName, coll2.databaseName)
        XCTAssertTrue(type(of: coll2).CollectionType.self == Document.self)

        let coll3 = db1.collection("collName3", withCollectionType: Int.self)
        XCTAssertTrue(type(of: coll3).CollectionType.self == Int.self)
    }
}
