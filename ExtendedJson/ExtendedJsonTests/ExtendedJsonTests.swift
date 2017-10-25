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
        XCTAssertEqual(num.toExtendedJson as! [String: String], [key: String(num)])
    }

    func testExtendedJsonRepresentableInt32() {
        let numInt32: Int32 = 42
        XCTAssertEqual(numInt32.toExtendedJson as! [String: String], ["$numberInt": String(numInt32)])
    }

    func testExtendedJsonRepresentableInt64() {
        let numInt64: Int64 = 42
        XCTAssertEqual(numInt64.toExtendedJson as! [String: String], ["$numberLong": String(numInt64)])
    }

    func testExtendedJsonRepresentableDouble() {
        let double: Double = 42
        XCTAssertEqual(double.toExtendedJson as! [String: String], ["$numberDouble": String(double)])
    }

    func testExtendedJsonRepresentableString() {
        let string = "MongoDB"
        XCTAssertEqual(string.toExtendedJson as! String, string)
    }

    func testExtendedJsonRepresentableDate() {
        let date = Date()
        if let dateExtJson = date.toExtendedJson as? [String: Any] {
            if let dateDictionary = dateExtJson["$date"] as? [String: String] {
                XCTAssertEqual(dateDictionary, ["$numberLong": String(Double(date.timeIntervalSince1970 * 1000))])
            } else {
                XCTFail("expected dictionary to have a $date key with a dictionary value from String to String.")
            }
        } else {
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
        XCTAssertEqual(objectId.toExtendedJson as! [String: String], ["$oid": hexString])
    }

    func testExtendedJsonRepresentableBinary() {
        let binary = BsonBinary(type: .binary, data: [77, 111, 110, 103, 111, 68, 66])
        let binaryActual = (binary.toExtendedJson as! [String: [String: String]])["$binary"]

        XCTAssertNotNil(binaryActual)
        XCTAssertNotNil(binaryActual!["base64"])
        XCTAssertNotNil(binaryActual!["subType"])

        XCTAssertEqual(binaryActual!["base64"]!, "TW9uZ29EQg==")
        XCTAssertEqual(binaryActual!["subType"]!, "0x0")
    }

    func testExtendedJsonRepresentableBsonTimestamp() {
        let date = Date()
        let bsonTimestamp = BsonTimestamp(time: date, increment: 1)
        let extJsonTimestamp = bsonTimestamp.toExtendedJson as! [String: [String: Any]]
        if let timestampJson = extJsonTimestamp["$timestamp"],
            let t = timestampJson["t"] as? Int64,
            let i = timestampJson["i"] as? Int {
            XCTAssertEqual(t, Int64(date.timeIntervalSince1970))
            XCTAssertEqual(i, 1)
        } else {
            XCTFail("timestamp missing.")
        }
    }

    func testExtendedJsonRepresentableRegularExpression() throws {
        let regex = try RegularExpression(pattern: "[0-9a-fA-F]+", options: [.dotMatchesLineSeparators, .caseInsensitive, .allowCommentsAndWhitespace, .anchorsMatchLines])

        let xjson = regex.toExtendedJson as! [String: [String: String]]
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
        XCTAssertEqual(MinKey().toExtendedJson as! [String: Int], ["$minKey": 1])
    }

    func testExtendedJsonRepresentableMaxKey() {
        XCTAssertEqual(MaxKey().toExtendedJson as! [String: Int], ["$maxKey": 1])
    }

    func testExtendedJsonRepresentableUndefined() {
        XCTAssertEqual(BsonUndefined().toExtendedJson as! [String: Bool], ["$undefined": true])
    }

    func testExtendedJsonRepresentableNull() {
        XCTAssertEqual(Null().toExtendedJson as! NSNull, NSNull())
    }

    func testExtendedJsonRepresentableDecimal() {
        XCTAssertEqual(Decimal(string: "85070591730234615847396907784232501249")?.toExtendedJson as! [String: String],
                       ["$numberDecimal": "85070591730234615847396907784232501249"])
    }

    func testExtendedJsonRepresentableBsonArray() {
        var array = BsonArray()
        let number = 42
        array.append(Int64(number))
        array.append("MongoDB")
        let extJsonArray = array.toExtendedJson as! [Any]
        XCTAssertEqual(extJsonArray[0] as! [String: String], ["$numberLong": String(number)])
        XCTAssertEqual(extJsonArray[1] as! String, "MongoDB")
    }

    func testExtendedJsonRepresentableDocument() {
        var document = BsonDocument()
        let number = 42
        document["number"] = Int64(number)
        document["string"] = "MongoDB"
        let extJsonDocument = document.toExtendedJson as! [String: Any]
        XCTAssertEqual(extJsonDocument["number"] as! [String: String], ["$numberLong": String(number)])
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
            "testDate": testDate,
            "testArray": [
                [
                    "testObjectId": hexString,
                    "testLong": testNumber
                ] as BsonDocument,
                [
                    "testObjectId": hexString,
                    "testLong": testNumber
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
        let extendedJson: [String: Any] = [
            "testObjectId": ["$oid": hexString],
            "testInt": ["$numberInt": numberAsString],
            "testLong": ["$numberLong": numberAsString],
            "testDouble": ["$numberDouble": numberAsString],
            "testString": "MongoDB",
            "testDate": ["$date": ["$numberLong": String(Int64(date.timeIntervalSince1970))]],
            "testTrue": true,
            "testFalse": false,
            "testBinary": ["$binary": ["base64": "TW9uZ29EQg==", "subType": "0x0"]],
            "testTimestamp": ["$timestamp": ["t": Int64(date.timeIntervalSince1970), "i": 1]],
            "testRegex": ["$regularExpression": ["pattern": "[0-9a-fA-F]+", "options": "i"]],
            "testMinKey": ["$minKey": 1],
            "testMaxKey": ["$maxKey": 1],
            "testNull": Null(),
            "testArray": [["testObjectId": ["$oid": hexString],
                            "testLong": ["$numberLong": numberAsString]],
                           ["testObjectId": ["$oid": hexString],
                            "testLong": ["$numberLong": numberAsString]]
            ]
        ]

        let document = try BsonDocument(extendedJson: extendedJson)
        XCTAssertEqual(document["testObjectId"] as! ObjectId, try ObjectId(hexString: hexString))
        XCTAssertEqual(document["testInt"] as? Int32, 42)
        XCTAssertEqual(document["testLong"] as? Int64, 42)
        XCTAssertEqual(document["testDouble"] as? Double, 42)
        XCTAssertEqual(document["testString"] as? String, "MongoDB")
        XCTAssertEqual(Int64((document["testDate"] as? Date)!.timeIntervalSince1970), Int64(date.timeIntervalSince1970))
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
