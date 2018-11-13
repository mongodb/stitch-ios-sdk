import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class ConflictHandlerUnitTests: XCTestCase {
    private struct TestCodable: Codable {
        let _id: ObjectId
        let foo: Int
        let bar: String
    }

    private class TestCodableConflictHandler: ConflictHandler {
        typealias DocumentT = TestCodable

        func resolveConflict(documentId: BSONValue,
                             localEvent: ChangeEvent<ConflictHandlerUnitTests.TestCodable>,
                             remoteEvent: ChangeEvent<ConflictHandlerUnitTests.TestCodable>) -> ConflictHandlerUnitTests.TestCodable? {
            XCTAssertEqual(ConflictHandlerUnitTests.documentId, documentId as! ObjectId)
            XCTAssertEqual(expectedLocalEvent.id, localEvent.id)
            XCTAssertEqual(expectedLocalEvent.operationType, localEvent.operationType)
            XCTAssertEqual(expectedLocalEvent.fullDocument?["foo"] as? Int, localEvent.fullDocument?.foo)
            XCTAssertEqual(expectedLocalEvent.fullDocument?["bar"] as? String, localEvent.fullDocument?.bar)
            XCTAssertEqual(expectedLocalEvent.fullDocument?["_id"] as? ObjectId, localEvent.fullDocument?._id)
            XCTAssertEqual(expectedLocalEvent.ns, localEvent.ns)
            XCTAssertEqual(expectedLocalEvent.documentKey, localEvent.documentKey)
            XCTAssertNil(localEvent.updateDescription)
            XCTAssertEqual(expectedLocalEvent.hasUncommittedWrites, localEvent.hasUncommittedWrites)

            XCTAssertEqual(expectedRemoteEvent.id, remoteEvent.id)
            XCTAssertEqual(expectedRemoteEvent.operationType, remoteEvent.operationType)
            XCTAssertEqual(expectedRemoteEvent.fullDocument?["foo"] as? Int, remoteEvent.fullDocument?.foo)
            XCTAssertEqual(expectedRemoteEvent.fullDocument?["bar"] as? String, remoteEvent.fullDocument?.bar)
            XCTAssertEqual(expectedRemoteEvent.fullDocument?["_id"] as? ObjectId, remoteEvent.fullDocument?._id)
            XCTAssertEqual(expectedRemoteEvent.ns, remoteEvent.ns)
            XCTAssertEqual(expectedRemoteEvent.documentKey, remoteEvent.documentKey)
            XCTAssertNil(remoteEvent.updateDescription)
            XCTAssertEqual(expectedLocalEvent.hasUncommittedWrites, remoteEvent.hasUncommittedWrites)

            return remoteEvent.fullDocument
        }
    }

    static let documentId = ObjectId()
    static let expectedLocalEvent = ChangeEvent<Document>.init(
        id: ["apples": "pears"],
        operationType: .insert,
        fullDocument: ["foo": 42, "bar": "baz", "_id": documentId],
        ns: MongoNamespace.init(databaseName: "beep", collectionName: "boop"),
        documentKey: ["_id": documentId],
        updateDescription: nil,
        hasUncommittedWrites: false)
    static let expectedRemoteEvent = ChangeEvent<Document>.init(
        id: ["oranges": "bananas"],
        operationType: .delete,
        fullDocument: ["_id": documentId, "foo": 84, "bar": "qux"],
        ns: MongoNamespace.init(databaseName: "beep", collectionName: "boop"),
        documentKey: ["_id": documentId],
        updateDescription: nil,
        hasUncommittedWrites: false)

    func testResolveConflict() {
        let conflictHandler = AnyConflictHandler(TestCodableConflictHandler())
        let resolution = conflictHandler.resolveConflict(documentId: ConflictHandlerUnitTests.documentId,
                                                         localEvent: ConflictHandlerUnitTests.expectedLocalEvent,
                                                         remoteEvent: ConflictHandlerUnitTests.expectedRemoteEvent)
        XCTAssertEqual(ConflictHandlerUnitTests.expectedRemoteEvent.fullDocument, resolution)
    }
}
