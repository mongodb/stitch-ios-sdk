//
//  CodableTests.swift
//  ExtendedJsonTests
//
//  Created by Jason Flax on 10/22/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import ExtendedJson

class CodableTests: XCTestCase {
    func testBsonDocumentCodable() throws {
        let data = try JSONSerialization.data(withJSONObject: specDocDict)
        let uh = try JSONSerialization.jsonObject(with: data)

        let bson = try BsonDecoder().decode(BsonDocument.self, from: data)
        print(bson)
    }
}
