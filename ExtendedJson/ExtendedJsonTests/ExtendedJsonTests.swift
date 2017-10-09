//
//  ExtendedJsonTests.swift
//  ExtendedJsonTests
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
        let binaryActual = (binary.toExtendedJson as! [String : [String : String]])["$binary"]
        
        XCTAssertNotNil(binaryActual)
        XCTAssertNotNil(binaryActual!["base64"])
        XCTAssertNotNil(binaryActual!["subType"])
        
        XCTAssertEqual(binaryActual!["base64"]!, "TW9uZ29EQg==")
        XCTAssertEqual(binaryActual!["subType"]!, "0x0")
    }
    
    func testExtendedJsonRepresentableBsonTimestamp() {
        let date = Date()
        let bsonTimestamp = BsonTimestamp(time: date, increment: 1)
        let extJsonTimestamp = bsonTimestamp.toExtendedJson as! [String : [String : Any]]
        if let timestampJson = extJsonTimestamp["$timestamp"],
            let t = timestampJson["t"] as? Double,
            let i = timestampJson["i"] as? Int {
            XCTAssertEqual(t, date.timeIntervalSince1970)
            XCTAssertEqual(i, 1)
        }
        else {
            XCTFail("timestamp missing.")
        }
    }
    
    func testExtendedJsonRepresentableRegularExpression() throws {
        let regex = try NSRegularExpression(pattern: "[0-9a-fA-F]+", options: [.dotMatchesLineSeparators, .caseInsensitive, .allowCommentsAndWhitespace, .anchorsMatchLines])
        
        let xjson = regex.toExtendedJson as! [String : [String: String]]
        if let regexJson = xjson["$regularExpression"],
            let pattern = regexJson["pattern"],
            let options = regexJson["options"] {
            XCTAssertEqual(pattern, "[0-9a-fA-F]+")
            XCTAssertEqual(options, "imsx")
        } else {
            XCTFail("NSRegularExpression.toExtendedJson failed")
        }
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
    
    func testExtendedJsonRepresentableDecimal() {
        XCTAssertEqual(Decimal(string: "85070591730234615847396907784232501249")?.toExtendedJson as! [String : String],
                       ["$numberDecimal": "85070591730234615847396907784232501249"])
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
        var document = BsonDocument()
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
        
        for _ in 0..<1000 {
            XCTAssertNotEqual(ObjectId.NewObjectId().hexString, ObjectId.NewObjectId().hexString)
        }
    }
    
    func testXJsonConversions() throws {
        let doc: BsonDocument = [
            "testOid": ObjectId.NewObjectId()
        ]
        
        XCTAssertTrue(doc["testOid"] is ObjectId)
    }
    
    func testDocumentLiteral() throws {
        let testNumber = 42
        let testDate = Int64(Date().timeIntervalSince1970 * 1000)
        let hexString = "1234567890abcdef12345678"
        let document: BsonDocument = [
            "testNumber": testNumber,
            "testDate" : testDate,
            "testArray" : [
                [
                    "testObjectId" : hexString,
                    "testLong" : testNumber
                ] as BsonDocument,
                [
                    "testObjectId" : hexString,
                    "testLong" : testNumber
                ] as BsonDocument
            ] as BsonArray
        ]
        
        XCTAssertEqual(document["testNumber"] as! Int, testNumber)
        XCTAssertEqual(document["testDate"] as! Int64, testDate)
        XCTAssert(document["testArray"] is BsonArray)
    }
    
    func testDocument() throws {
        let hexString = "1234567890abcdef12345678"
        let date = Date()
        let binary = BsonBinary(type: .binary, data: [77, 111, 110, 103, 111, 68, 66])
        let extJsonTimestamp = BsonTimestamp(time: date, increment: 1)
        let regex = try NSRegularExpression(pattern: "[0-9a-fA-F]+", options: .caseInsensitive)
        
        let number = 42
        let numberAsString = String(number)
        let extendedJson: [String : Any] = [
            "testObjectId" : ["$oid" : hexString],
            "testInt" : ["$numberInt" : numberAsString],
            "testLong" : ["$numberLong" : numberAsString],
            "testDouble" : ["$numberDouble" : numberAsString],
            "testString" : "MongoDB",
            "testDate" : ["$date" : ["$numberLong" : String(Int64(date.timeIntervalSince1970))]],
            "testTrue" : true,
            "testFalse" : false,
            "testBinary" : ["$binary" : ["base64": "TW9uZ29EQg==", "subType" : "0x0"]],
            "testTimestamp" : ["$timestamp" : ["t": Int(date.timeIntervalSince1970), "i": 1]],
            "testRegex" : ["$regularExpression" : ["pattern": "[0-9a-fA-F]+", "options" : "i"]],
            "testMinKey" : ["$minKey" : 1],
            "testMaxKey" : ["$maxKey" : 1],
            "testNull" : NSNull(),
            "testArray" : [["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]],
                           ["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]]
            ]
        ]
        
        let document = try BsonDocument(extendedJson: extendedJson)
        XCTAssertEqual(document["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
        XCTAssertEqual(document["testInt"] as? Int32, 42)
        XCTAssertEqual(document["testLong"] as? Int64, 42)
        XCTAssertEqual(document["testDouble"] as? Double, 42)
        XCTAssertEqual(document["testString"] as? String, "MongoDB")
        XCTAssertEqual(Int((document["testDate"] as? Date)!.timeIntervalSince1970), Int(date.timeIntervalSince1970))
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
        
        XCTAssertEqual((embeddedArray[0] as! BsonDocument)["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
        XCTAssertEqual((embeddedArray[0] as! BsonDocument)["testLong"] as! Int64, 42)
        
        XCTAssertEqual((embeddedArray[1] as! BsonDocument)["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
        XCTAssertEqual((embeddedArray[1] as! BsonDocument)["testLong"] as! Int64, 42)
    }
    
    func testRoundTrip() throws {
        let _id = "_id"
        let symbol = "Symbol"
        let string = "String"
        let int32 = "Int32"
        let int64 = "Int64"
        let double = "Double"
        let specialFloat = "SpecialFloat"
        let decimal = "Decimal"
        let binary = "Binary"
        let binaryUserDefined = "BinaryUserDefined"
        let code = "Code"
        let codeWithScope = "CodeWithScope"
        let subDocument = "SubDocument"
        let array = "Array"
        let timestamp = "Timestamp"
        let regularExpression = "RegularExpression"
        let datetimeEpoch = "DatetimeEpoch"
        let datetimePositive = "DatetimePositive"
        let datetimeNegative = "DatetimeNegative"
        let `true` = "True"
        let `false` = "False"
        let dbPointer = "DBPointer"
        let dbRef = "DBRef"
        let dbRefNoDB = "DBRefNoDB"
        let minKey = "MinKey"
        let maxKey = "MaxKey"
        let null = "Null"
        let undefined = "Undefined"
        
        let keys = [_id, symbol, string, int32, int64, double, specialFloat, decimal,
                    binary, binaryUserDefined, code, codeWithScope, subDocument,
                    array, timestamp, regularExpression, datetimeEpoch, datetimePositive,
                    datetimeNegative, `true`, `false`, dbPointer, dbRef, dbRefNoDB,
                    minKey, maxKey, null, undefined]
        
        let goodDoc: BsonDocument = [
            _id: try ObjectId(hexString: "57e193d7a9cc81b4027498b5"),
            symbol: BsonSymbol("symbol"),
            string: "string",
            int32: Int32(42),
            int64: Int64(42),
            double: 42.42,
            specialFloat: Double.nan,
            decimal: Decimal(1234),
            binary: UUID(uuidString: "a34c38f7-c3ab-edc8-a378-14a992ab8db6")!,
            binaryUserDefined: BsonBinary(type: BsonBinarySubType(rawValue: 0x80)!,
                                          data: [UInt8](arrayLiteral: 1, 2, 3, 4, 5)),
            code: BsonCode(code: "function() {}"),
            codeWithScope: BsonCode(code: "function() {}", scope: BsonDocument()),
            subDocument: try BsonDocument(key: "foo", value: "bar"),
            array: [1, 2, 3, 4, 5] as BsonArray,
            timestamp: BsonTimestamp(time: 42, increment: 1),
            regularExpression: try NSRegularExpression(pattern: "foo*", options: NSRegularExpression.Options("xi")),
            datetimeEpoch: Date(timeIntervalSince1970: TimeInterval(0)),
            datetimePositive: Date(timeIntervalSince1970: TimeInterval(Int64.max)),
            datetimeNegative: Date(timeIntervalSince1970: TimeInterval(Int64.min)),
            `true`: true,
            `false`: false,
            dbPointer: BsonDBPointer(ref: "db.collection",
                                     id: try ObjectId(hexString: "57e193d7a9cc81b4027498b1")),
            dbRef: BsonDBRef(ref: "collection",
                             id: try ObjectId(hexString: "57fd71e96e32ab4225b723fb"),
                             db: "database",
                             otherFields: [:]),
            dbRefNoDB: BsonDBRef(ref: "collection",
                                 id: try ObjectId(hexString: "57fd71e96e32ab4225b723fb"),
                                 db: nil,
                                 otherFields: [:]),
            minKey: MinKey(),
            maxKey: MaxKey(),
            null: NSNull(),
            undefined: BsonUndefined()
        ]
        
        let badDoc: BsonDocument = [
            _id: ObjectId.NewObjectId(),
            symbol: BsonSymbol("lobmys"),
            string: "gnirts",
            int32: Int32(24),
            int64: Int64(24),
            double: 24.24,
            specialFloat: Double.infinity,
            decimal: Decimal(4321),
            binary: UUID(uuidString: "c8edabc3-f739-4ca3-b68d-ab92a91478a3")!,
            binaryUserDefined: BsonBinary(type: BsonBinarySubType(rawValue: 0x80)!,
                                          data: [UInt8](arrayLiteral: 6, 7, 8, 9, 10)),
            code: BsonCode(code: "function() { console.log('foo') }"),
            codeWithScope: BsonCode(code: "function() { console.log('foo') }", scope: BsonDocument()),
            subDocument: try BsonDocument(key: "baz", value: "qux"),
            array: [6, 7, 8, 9, 10] as BsonArray,
            timestamp: BsonTimestamp(time: 24, increment: 2),
            regularExpression: try NSRegularExpression(pattern: "bar*", options: NSRegularExpression.Options("xi")),
            datetimeEpoch: Date.timeIntervalSinceReferenceDate,
            datetimePositive: Date(timeIntervalSince1970: TimeInterval(Int64.min)),
            datetimeNegative: Date(timeIntervalSince1970: TimeInterval(Int64.max)),
            `true`: false,
            `false`: true,
            dbPointer: BsonDBPointer(ref: "db.collection",
                                     id: ObjectId.NewObjectId()),
            dbRef: BsonDBRef(ref: "collection",
                             id: ObjectId.NewObjectId(),
                             db: "database",
                             otherFields: [:]),
            dbRefNoDB: BsonDBRef(ref: "collection",
                                 id: ObjectId.NewObjectId(),
                                 db: nil,
                                 otherFields: [:]),
            minKey: MaxKey(),
            maxKey: MinKey(),
            null: "nil",
            undefined: "undefined"
        ]
        
        let specDocDict: [String : Any?] = [
            _id: [
                "$oid": "57e193d7a9cc81b4027498b5"
            ],
            symbol: [
                "$symbol": "symbol"
            ],
            string: "string",
            int32: [
                "$numberInt": "42"
            ],
            int64: [
                "$numberLong": "42"
            ],
            double: [
                "$numberDouble": "42.42"
            ],
            specialFloat: [
                "$numberDouble": "NaN"
            ],
            decimal: [
                "$numberDecimal": "1234"
            ],
            binary: [
                "$binary": [
                    "base64": "o0w498Or7cijeBSpkquNtg==",
                    "subType": "03"
                ]
            ],
            binaryUserDefined: [
                "$binary": [
                    "base64": "AQIDBAU=",
                    "subType": "80"
                ]
            ],
            code: [
                "$code": "function() {}"
            ],
            codeWithScope: [
                "$code": "function() {}",
                "$scope": []
            ],
            subDocument: [
                "foo": "bar"
            ],
            array: [
                ["$numberInt": "1"],
                ["$numberInt": "2"],
                ["$numberInt": "3"],
                ["$numberInt": "4"],
                ["$numberInt": "5"]
            ],
            timestamp: [
                "$timestamp": [ "t": 42, "i": 1 ]
            ],
            regularExpression: [
                "$regularExpression": [
                    "pattern": "foo*",
                    "options": "ix"
                ]
            ],
            datetimeEpoch: [
                "$date": [
                    "$numberLong": "0"
                ]
            ],
            datetimePositive: [
                "$date": [
                    "$numberLong": "9223372036854775807"
                ]
            ],
            datetimeNegative: [
                "$date": [
                    "$numberLong": "-9223372036854775808"
                ]
            ],
            `true`: true,
            `false`: false,
            dbPointer: [
                "$dbPointer": [
                    "$ref": "db.collection",
                    "$id": [
                        "$oid": "57e193d7a9cc81b4027498b1"
                    ]
                ]
            ],
            dbRef: [
                "$ref": "collection",
                "$id": [
                    "$oid": "57fd71e96e32ab4225b723fb"
                ],
                "$db": "database"
            ],
            dbRefNoDB: [
                "$ref": "collection",
                "$id": [
                    "$oid": "57fd71e96e32ab4225b723fb"
                ]
            ],
            minKey: [
                "$minKey": 1
            ],
            maxKey: [
                "$maxKey": 1
            ],
            null: nil,
            undefined: [
                "$undefined": true
            ]
        ]
        
        let specDoc = try BsonDocument.init(extendedJson: specDocDict)
        
        keys.forEach { (key) in
            print()
            XCTAssertTrue(specDoc[key]!.isEqual(toOther: goodDoc[key]!),
                          "key: \(key) .. specDoc: \(String(describing: specDoc[key])) .. goodDoc: \(String(describing: goodDoc[key]))")
            XCTAssertFalse(specDoc[key]!.isEqual(toOther: badDoc[key]!),
                           "key: \(key) .. specDoc: \(String(describing: specDoc[key])) .. badDoc: \(String(describing: badDoc[key]))")
        }
    }
}
