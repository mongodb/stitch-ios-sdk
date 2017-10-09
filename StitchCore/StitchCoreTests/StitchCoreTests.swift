import XCTest
@testable import StitchCore
import ExtendedJson

class StitchCoreTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPipelineToJson() throws {
        
        // setup
        let hexString = "1234567890abcdef12345678"
        let objectId = try ObjectId(hexString: hexString)
        let date = Date()
        var array = BsonArray()
        let number = 42
        var embeddedDoc: BsonDocument = [
            "testObjectId": objectId,
            "testLong": Int64(number)
        ]
        embeddedDoc["testObjectId"] = objectId
        embeddedDoc["testLong"] = Int64(number)
        array.append(embeddedDoc)
        array.append(embeddedDoc)// add the same document twice
        
        let dbRefId = ObjectId.NewObjectId()
        
        // create pipline to test
        let pipeline = Pipeline(action: "testAction", service: "testService", args: [
            "testObjectId" : objectId,
            "testInt" : Int32(number),
            "testLong" : Int64(number),
            "testDouble" : Double(number),
            "testString" : "MongoDB",
            "testDate" : date,
            "testTrue" : true,
            "testFalse" : false,
            "testBinary" : BsonBinary(type: .binary, data: [77, 111, 110, 103, 111, 68, 66]),
            "testTimestamp" : BsonTimestamp(time: date, increment: 1),
            "testRegex" : try NSRegularExpression(pattern: "[0-9a-fA-F]+", options: .caseInsensitive),
            "testMinKey" : MinKey(),
            "testMaxKey" : MaxKey(),
            "testArray" : array,
            "testCode": BsonCode(code: "foo", scope: ["bar": "baz"]),
            "testRef": BsonDBRef(ref: "foo", id: dbRefId, db: "bar", otherFields: [:])
        ])
        
        let pipelineJson = pipeline.toJson
        
        XCTAssertEqual(pipelineJson["action"] as! String, "testAction")
        XCTAssertEqual(pipelineJson["service"] as! String, "testService")
        
        // the expected args result as extended json
        let numberAsString = String(number)
        let dateAsString = String(UInt64(date.timeIntervalSince1970 * 1000))
        let expectedArgsExtendedJson: [String : Any] = [
            "testObjectId" : ["$oid" : hexString],
            "testInt" : ["$numberInt" : numberAsString],
            "testLong" : ["$numberLong" : numberAsString],
            "testDouble" : ["$numberDouble" : numberAsString],
            "testString" : "MongoDB",
            "testDate" : ["$date" : ["$numberLong" : dateAsString]],
            "testTrue" : true,
            "testFalse" : false,
            "testBinary" : ["$binary" : ["base64" : "TW9uZ29EQg==", "subType" : "0x0"]],
            "testTimestamp" : ["$timestamp" : ["t": (UInt64(date.timeIntervalSince1970)), "i": 1]],
            "testRegex" : ["$regularExpression" :["pattern": "[0-9a-fA-F]+", "options" : "i"]],
            "testMinKey" : ["$minKey" : 1],
            "testMaxKey" : ["$maxKey" : 1],
            "testArray" : [["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]],
                           ["testObjectId" : ["$oid" : hexString],
                            "testLong" : ["$numberLong" : numberAsString]]
            ],
            "testCode": ["$code": "foo", "$scope": ["bar": "baz"]],
            "testRef": ["$ref": "foo", "$id": ["$oid": dbRefId.hexString], "$db": "bar"]
        ]
        
        do {
            // create documents from the generated args result and from the expected result
            let document = try BsonDocument(extendedJson: pipelineJson["args"] as! [String : Any])
            let expectedDocument = try BsonDocument(extendedJson: expectedArgsExtendedJson)
            
            XCTAssertEqual(document["testObjectId"] as! ObjectId, expectedDocument["testObjectId"] as! ObjectId)
            XCTAssertEqual(document["testInt"] as? Int32, expectedDocument["testInt"] as? Int32)
            XCTAssertEqual(document["testLong"] as? Int64, expectedDocument["testLong"] as? Int64)
            XCTAssertEqual(document["testDouble"] as? Double, expectedDocument["testDouble"] as? Double)
            XCTAssertEqual(document["testString"] as? String, expectedDocument["testString"] as? String)
            XCTAssertEqual(Int64((document["testDate"] as? Date)!.timeIntervalSince1970),
                           Int64(date.timeIntervalSince1970 * 1000))
            XCTAssertEqual(document["testTrue"] as? Bool, expectedDocument["testTrue"] as? Bool)
            XCTAssertEqual(document["testFalse"] as? Bool, expectedDocument["testFalse"] as? Bool)
            XCTAssertEqual(document["testBinary"] as? BsonBinary, expectedDocument["testBinary"] as? BsonBinary)
            XCTAssertEqual(document["testTimestamp"] as? BsonTimestamp, expectedDocument["testTimestamp"] as? BsonTimestamp)
            XCTAssertEqual(document["testRegex"] as? NSRegularExpression, expectedDocument["testRegex"] as? NSRegularExpression)
            XCTAssertEqual(document["testMinKey"] as? MinKey, expectedDocument["testMinKey"] as? MinKey)
            XCTAssertEqual(document["testMaxKey"] as? MaxKey, expectedDocument["testMaxKey"] as? MaxKey)
            
            let embeddedArray = document["testArray"] as! BsonArray
            let expectedEmbeddedArray = expectedDocument["testArray"] as! BsonArray
            
            XCTAssertEqual(embeddedArray.count, expectedEmbeddedArray.count)
            
            XCTAssertEqual((embeddedArray[0] as! BsonDocument)["testObjectId"] as! ObjectId, (expectedEmbeddedArray[0] as! BsonDocument)["testObjectId"] as! ObjectId)
            XCTAssertEqual((embeddedArray[0] as! BsonDocument)["testLong"] as! Int64, (expectedEmbeddedArray[0] as! BsonDocument)["testLong"] as! Int64)
            
            XCTAssertEqual((embeddedArray[1] as! BsonDocument)["testObjectId"] as! ObjectId, (expectedEmbeddedArray[1] as! BsonDocument)["testObjectId"] as! ObjectId)
            XCTAssertEqual((embeddedArray[1] as! BsonDocument)["testLong"] as! Int64, (expectedEmbeddedArray[1] as! BsonDocument)["testLong"] as! Int64)
            
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    
    
}
