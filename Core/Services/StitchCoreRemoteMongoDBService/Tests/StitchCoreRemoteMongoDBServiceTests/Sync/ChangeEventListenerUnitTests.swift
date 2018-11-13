import Foundation
import XCTest
import MongoMobile
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class ChangeEventListenerUnitTests: XCTestCase {
    private struct TestCodable: Codable {
        let _id: ObjectId
        let foo: Int
        let bar: String
    }

    private class TestCodableChangeEventListener: ChangeEventListener {
        typealias DocumentT = TestCodable

        func onEvent(documentId: BSONValue, event: ChangeEvent<ChangeEventListenerUnitTests.TestCodable>) {
            XCTAssertEqual(ChangeEventListenerUnitTests.documentId, documentId as! ObjectId)
            XCTAssertEqual(expectedChangeEvent.id, event.id)
            XCTAssertEqual(expectedChangeEvent.operationType, event.operationType)
            XCTAssertEqual(expectedChangeEvent.fullDocument?["foo"] as? Int, event.fullDocument?.foo)
            XCTAssertEqual(expectedChangeEvent.fullDocument?["bar"] as? String, event.fullDocument?.bar)
            XCTAssertEqual(expectedChangeEvent.fullDocument?["_id"] as? ObjectId, event.fullDocument?._id)
            XCTAssertEqual(expectedChangeEvent.ns, event.ns)
            XCTAssertEqual(expectedChangeEvent.documentKey, event.documentKey)
            XCTAssertNil(event.updateDescription)
            XCTAssertEqual(expectedChangeEvent.hasUncommittedWrites, event.hasUncommittedWrites)
        }
    }

    private static let documentId = ObjectId()
    private static let expectedChangeEvent = ChangeEvent<Document>.init(
        id: ["apples": "pears"],
        operationType: .insert,
        fullDocument: ["foo": 42, "bar": "baz", "_id": documentId],
        ns: MongoNamespace.init(databaseName: "beep", collectionName: "boop"),
        documentKey: ["_id": documentId],
        updateDescription: nil,
        hasUncommittedWrites: false)

    func testOnEvent() {
        let changeEventListener = AnyChangeEventListener(TestCodableChangeEventListener())
        changeEventListener.onEvent(documentId: ChangeEventListenerUnitTests.documentId,
                                    event: ChangeEventListenerUnitTests.expectedChangeEvent)
    }
}
