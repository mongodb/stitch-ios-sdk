//
//  HashUtilsTests.swift
//  StitchCoreRemoteMongoDBServiceTests
//
//  Created by Douglas Kaminsky on 4/16/19.
//

import MongoSwift
@testable import StitchCoreRemoteMongoDBService
import XCTest

class HashUtilsTests: XCTestCase {
    let expectedEmptyHashValue: Int64 = -6534195273556634272
    let expectedHelloWorldHashValue: Int64 = 3488831889965352219
    let expectedTypicalBSONDocumentHashValue: Int64 = 2637880642529775697

    let emptyDocument: Document = Document()
    let helloWorldDocument = ["hello": "world"] as Document
    let typicalDocument = ["_id": ObjectId(fromString: "5cb8a847a8d14019f59b99f0"),
                           "foo": ["hello": "world",
                                   "ways to leave":
                                    ["make a new plan, Stan",
                                     "sneak out the back, Jack",
                                     "no need to be coy, Roy",
                                     "just hop on the bus, Gus",
                                     "drop off the key, Lee"]] as Document,
                           "bar": 42,
                           "baz": "metasyntactic variables rule",
                           "quux": true] as Document

    func testEmptyHashResult() {
        XCTAssertEqual(expectedEmptyHashValue, HashUtils.hash(doc: emptyDocument))
    }

    func testHelloWorldHashResult() {
        XCTAssertEqual(expectedHelloWorldHashValue, HashUtils.hash(doc: helloWorldDocument))
    }

    func testTypicalHashResult() {
        print(typicalDocument)
        XCTAssertEqual(expectedTypicalBSONDocumentHashValue, HashUtils.hash(doc: typicalDocument))
    }
}
