//
//  ExtendedJsonTests.swift
//  ExtendedJsonTests
//
//  Created by Ofer Meroz on 16/02/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import XCTest
@testable import ExtendedJson

class ExtendedJsonTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExtendedJsonRepresentableInt() {
        let num = 42
        var key = "$numberLong"
        if MemoryLayout<Int>.size == MemoryLayout<Int32>.size {
            key = "$numberInt"
        }
        XCTAssertEqual(num.toExtendedJson as! [String : String], [key : String(num)])
    }
    
    func testExtendedJsonRepresentableInt32() {
        let numInt32: Int32 = 42
        XCTAssertEqual(numInt32.toExtendedJson as! [String : String], ["$numberInt" : String(numInt32)])
    }
    
    func testExtendedJsonRepresentableInt64() {
        let numInt64: Int64 = 42
        XCTAssertEqual(numInt64.toExtendedJson as! [String : String], ["$numberLong" : String(numInt64)])
    }
    
    func testExtendedJsonRepresentableDouble() {
        let double: Double = 42
        XCTAssertEqual(double.toExtendedJson as! [String : String], ["$numberDouble" : String(double)])
    }
    
    func testExtendedJsonRepresentableString() {
        let string = "MongoDB"
        XCTAssertEqual(string.toExtendedJson as! String, string)
    }
    
    func testExtendedJsonRepresentableDate() {
        let date = Date()
        if let dateExtJson = date.toExtendedJson as? [String : Any] {
            if let dateDictionary = dateExtJson["$date"] as? [String : String] {
                XCTAssertEqual(dateDictionary, ["$numberLong" : String(Int64(date.timeIntervalSince1970 * 1000))])
            }
            else {
                XCTFail("expected dictionary to have a $date key with a dictionary value from String to String.")
            }
        }
        else {
            XCTFail("expected dictionary from String to Any.")
        }
    }
    
    func testExtendedJsonRepresentableBool() {
        XCTAssertEqual(true.toExtendedJson as! Bool, true)
        XCTAssertEqual(false.toExtendedJson as! Bool, false)
    }
    
    func testExtendedJsonRepresentableObjectId() throws {
        let hexString = "1234567890abcdef12345678"
        let objectId = try ObjectId(hexString: hexString)
        XCTAssertEqual(objectId.toExtendedJson as! [String : String], ["$oid" : hexString])
    }

    
    func testExtendedJsonRepresentableBinary() {
        let binary = BsonBinary(type: .binary, data: [77, 111, 110, 103, 111, 68, 66])
        XCTAssertEqual(binary.toExtendedJson as! [String : String], ["$binary" : "TW9uZ29EQg==", "$type" : "0x0"])
    }
    
    func testExtendedJsonRepresentableBsonTimestamp() {
        let date = Date()        
        let extJsonTimestamp = BsonTimestamp(time: date).toExtendedJson as! [String : String]
        if let timestamp = extJsonTimestamp["$timestamp"],
            let t = TimeInterval(timestamp) {
            XCTAssertEqual(UInt64(t), UInt64(date.timeIntervalSince1970))
        }
        else {
            XCTFail("timestamp missing.")
        }
    }
    
    func testExtendedJsonRepresentableRegularExpression() throws {
        let regex = try NSRegularExpression(pattern: "[0-9a-fA-F]+", options: [.dotMatchesLineSeparators, .caseInsensitive, .allowCommentsAndWhitespace, .anchorsMatchLines])
        XCTAssertEqual(regex.toExtendedJson as! [String : String], ["$regex" : "[0-9a-fA-F]+", "$options" : "imsx"])
    }
    
    func testExtendedJsonRepresentableMinKey() {
        XCTAssertEqual(MinKey().toExtendedJson as! [String : Int], ["$minKey" : 1])
    }
    
    func testExtendedJsonRepresentableMaxKey() {
        XCTAssertEqual(MaxKey().toExtendedJson as! [String : Int], ["$maxKey" : 1])
    }
    
    func testExtendedJsonRepresentableUndefined() {
        XCTAssertEqual(BsonUndefined().toExtendedJson as! [String : Bool], ["$undefined" : true])
    }
    
    func testExtendedJsonRepresentableNull() {
        XCTAssertEqual(NSNull().toExtendedJson as! NSNull, NSNull())
    }
    
    func testExtendedJsonRepresentableBsonArray() {
        var array = BsonArray()
        let number = 42
        array.append(Int64(number))
        array.append("MongoDB")
        let extJsonArray = array.toExtendedJson as! [Any]
        XCTAssertEqual(extJsonArray[0] as! [String : String], ["$numberLong" : String(number)])
        XCTAssertEqual(extJsonArray[1] as! String, "MongoDB")
    }
    
    func testExtendedJsonRepresentableDocument() {
        var document = Document()
        let number = 42
        document["number"] = Int64(number)
        document["string"] = "MongoDB"
        let extJsonDocument = document.toExtendedJson as! [String : Any]
        XCTAssertEqual(extJsonDocument["number"] as! [String : String], ["$numberLong" : String(number)])
        XCTAssertEqual(extJsonDocument["string"] as! String, "MongoDB")
    }
    
    func testObjectId() {
        // test working initialization with hex string
        let hexString = "1234567890abcdef12345678"
        XCTAssertEqual(hexString, try ObjectId(hexString: hexString).hexString)
        
        // test invalid hex string
        let nonHexString = "mongodmongodmongodmongod"        
        XCTAssertThrowsError(try ObjectId(hexString: nonHexString))
        
        // test too short hex string
        let shortHexString = "42"
        XCTAssertThrowsError(try ObjectId(hexString: shortHexString))
        
        // test too long hex string
        let longHexString = "1234567890123456789012345"
        XCTAssertThrowsError(try ObjectId(hexString: longHexString))
        
        // test default initializer
        let objectId = ObjectId()
        XCTAssertTrue(ObjectId.isValid(hexString: objectId.hexString))
        
        //test equality
        XCTAssertEqual(try ObjectId(hexString: hexString), try ObjectId(hexString: hexString))

       
    }
    
    func testDocument() throws {
        let hexString = "1234567890abcdef12345678"
        let date = Date()
        let binary = BsonBinary(type: .binary, data: [77, 111, 110, 103, 111, 68, 66])
        let extJsonTimestamp = BsonTimestamp(time: date)
        let regex = try NSRegularExpression(pattern: "[0-9a-fA-F]+", options: .caseInsensitive)
        
        let number = 42
        let numberAsString = String(number)
        let extendedJson: [String : Any] = [
            "testObjectId" : ["$oid" : hexString],
            "testInt" : ["$numberInt" : numberAsString],
            "testLong" : ["$numberLong" : numberAsString],
            "testDouble" : ["$numberDouble" : numberAsString],
            "testString" : "MongoDB",
            "testDate" : ["$date" : ["$numberLong" : String(Int64(date.timeIntervalSince1970 * 1000))]],
            "testTrue" : true,
            "testFalse" : false,
            "testBinary" : ["$binary" : "TW9uZ29EQg==", "$type" : "0x0"],
            "testTimestamp" : ["$timestamp" : String(UInt64(date.timeIntervalSince1970))],
            "testRegex" : ["$regex" :"[0-9a-fA-F]+", "$options" : "i"],
            "testMinKey" : ["$minKey" : 1],
            "testMaxKey" : ["$maxKey" : 1],
            "testNull" : NSNull(),
            "testArray" : [["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]],
                           ["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]]
            ]
        ]
        
        do {
            let document = try Document(extendedJson: extendedJson)
            
            XCTAssertEqual(document["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
            XCTAssertEqual(document["testInt"] as? Int, 42)
            XCTAssertEqual(document["testLong"] as? Int, 42)
            XCTAssertEqual(document["testDouble"] as? Double, 42)
            XCTAssertEqual(document["testString"] as? String, "MongoDB")
            XCTAssertEqual(Int((document["testDate"] as? Date)!.timeIntervalSince1970 * 1000), Int(date.timeIntervalSince1970 * 1000))
            XCTAssertEqual(document["testTrue"] as? Bool, true)
            XCTAssertEqual(document["testFalse"] as? Bool, false)
            XCTAssertEqual(document["testBinary"] as? BsonBinary, binary)
            XCTAssertEqual(document["testTimestamp"] as? BsonTimestamp, extJsonTimestamp)
            XCTAssertEqual(document["testRegex"] as? NSRegularExpression, regex)
            XCTAssertEqual(document["testMinKey"] as? MinKey, MinKey())
            XCTAssertEqual(document["testMaxKey"] as? MaxKey, MaxKey())
            XCTAssertEqual(document["testNull"] as? NSNull, NSNull())
            
            let embeddedArray = document["testArray"] as! BsonArray
            
            XCTAssertEqual(embeddedArray.count, 2)
            
            XCTAssertEqual((embeddedArray[0] as! Document)["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
            XCTAssertEqual((embeddedArray[0] as! Document)["testLong"] as! Int, 42)
            
            XCTAssertEqual((embeddedArray[1] as! Document)["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
            XCTAssertEqual((embeddedArray[1] as! Document)["testLong"] as! Int, 42)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}
