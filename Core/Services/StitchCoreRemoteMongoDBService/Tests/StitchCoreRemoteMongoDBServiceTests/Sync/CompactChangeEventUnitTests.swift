import Foundation
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService

class CompactChangeEventUnitTests: XCTestCase {
    private func compare<T: Codable>(expectedChangeEvent: CompactChangeEvent<T>,
                                     to actualChangeEvent: CompactChangeEvent<T>) throws {
        XCTAssertEqual(expectedChangeEvent.operationType, actualChangeEvent.operationType)
        XCTAssertEqual(try BSONEncoder().encode(expectedChangeEvent.fullDocument),
                       try BSONEncoder().encode(actualChangeEvent.fullDocument))
        XCTAssertEqual(expectedChangeEvent.documentKey, actualChangeEvent.documentKey)
        XCTAssertEqual(expectedChangeEvent.updateDescription?.asUpdateDocument,
                       actualChangeEvent.updateDescription?.asUpdateDocument)
        XCTAssertEqual(expectedChangeEvent.stitchDocumentHash, actualChangeEvent.stitchDocumentHash)
        XCTAssertEqual(expectedChangeEvent.hasUncommittedWrites, actualChangeEvent.hasUncommittedWrites)
    }

    func testRoundTrip() throws {
        let documentKey = ObjectId()
        let insertEvent = try BSONDecoder().decode(CompactChangeEvent<Document>.self, from: """
            {
            "ot" : "insert",
            "fd" : { "foo": "bar" },
            "dk" : { "_id" : "\(documentKey.hex)" },
            "ud" : null,
            "sdh": 42
            }
            """)

        var expectedChangeEvent = CompactChangeEvent<Document>.init(
            operationType: .insert,
            fullDocument: ["foo": "bar"],
            documentKey: ["_id": documentKey.hex],
            updateDescription: nil,
            hasUncommittedWrites: false,
            stitchDocumentHash: 42,
            stitchDocumentVersion: nil)

        try compare(expectedChangeEvent: expectedChangeEvent, to: insertEvent)

        let unknownEvent = try BSONDecoder().decode(CompactChangeEvent<Document>.self, from: """
            {
            "ot" : "__lolwut__",
            "fd" : { "foo": "bar" },
            "dk" : { "_id" : "\(documentKey.hex)" },
            "ud" : null,
            "sdh": 42
            }
            """)

        expectedChangeEvent = CompactChangeEvent<Document>.init(
            operationType: .unknown,
            fullDocument: ["foo": "bar"],
            documentKey: ["_id": documentKey.hex],
            updateDescription: nil,
            hasUncommittedWrites: false,
            stitchDocumentHash: 42,
            stitchDocumentVersion: nil)

        try compare(expectedChangeEvent: expectedChangeEvent, to: unknownEvent)
    }
}
