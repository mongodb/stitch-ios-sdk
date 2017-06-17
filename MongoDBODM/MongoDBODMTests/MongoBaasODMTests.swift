//
//  MongoBaasODMTests.swift
//  MongoBaasODMTests
//

import XCTest
@testable import MongoDBODM
import ExtendedJson
import MongoDBService

class MongoBaasODMTests: XCTestCase {
    
    override func setUp() {
        super.setUp()        
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testProjectionWithArray() {
        let array = ["name", "age"]
        let projection = Projection(array)
        let projectionDocument = projection.asDocument
        
        XCTAssertEqual(projectionDocument["name"] as? Bool, true)
        XCTAssertEqual(projectionDocument["age"] as? Bool, true)
    }
    
    func testProjectionWithArrayLiteral() {
        let projection = ["name", "age"] as Projection
        let projectionDocument = projection.asDocument

        XCTAssertEqual(projectionDocument["name"] as? Bool, true)
        XCTAssertEqual(projectionDocument["age"] as? Bool, true)
    }

}
