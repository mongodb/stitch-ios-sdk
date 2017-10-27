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
    fileprivate func assertCodable<T>(original: T) throws where T: Codable & ExtendedJsonRepresentable {
        func run(shouldIncludeSourceMap: Bool) throws {
            let data = try BSONEncoder().encode(original, shouldIncludeSourceMap: shouldIncludeSourceMap)
            XCTAssertNotNil(try? T.fromExtendedJson(
                xjson: try! JSONSerialization.jsonObject(with: data, options: .allowFragments)))
            let new = try BSONDecoder().decode(T.self, from: data, hasSourceMap: shouldIncludeSourceMap)
            XCTAssert(original.isEqual(toOther: new))
        }

        try run(shouldIncludeSourceMap: true)
        try run(shouldIncludeSourceMap: false)
    }

    func testObjectIdCodable() throws {
        let oid = ObjectId.NewObjectId()
        try assertCodable(original: oid)
    }

    func testBsonBinaryCodable() throws {
        let bsonBinary = goodDoc[binaryUserDefined] as! Binary
        try assertCodable(original: bsonBinary)
    }

    func testBsonCodeCodable() throws {
        let bsonCode = goodDoc[codeWithScope] as! Code
        try assertCodable(original: bsonCode)
    }

    func testBSONDBPointerCodable() throws {
        let bsonDbPointer = goodDoc[dbPointer] as! DBPointer
        try assertCodable(original: bsonDbPointer)  
    }

    func testBSONRoundTrip() throws {
        let data = try JSONSerialization.data(withJSONObject: specDocDict)
        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        let doc = try Document.fromExtendedJson(xjson: json) as! Document
        try BSONDecoder().decode(SpecDocStruct.self, from: doc)
    }
}
