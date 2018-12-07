import XCTest
import Foundation
import MongoMobile
@testable import StitchCoreLocalMongoDBService
@testable import StitchCoreRemoteMongoDBService

final class CoreRemoteMongoClientUnitTests: XCMongoMobileTestCase {
    func testGetDatabase() throws {        
        let db1 = coreRemoteMongoClient.db("dbName1")
        XCTAssertEqual("dbName1", db1.name)
        
        let db2 = coreRemoteMongoClient.db("dbName2")
        XCTAssertEqual("dbName2", db2.name)
    }
}
