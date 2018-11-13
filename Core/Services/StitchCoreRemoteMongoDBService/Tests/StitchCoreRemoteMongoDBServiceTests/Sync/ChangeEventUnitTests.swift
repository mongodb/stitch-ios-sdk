import Foundation
import XCTest
import MongoSwift
@testable import StitchCoreRemoteMongoDBService

class ChangeEventUnitTests: XCTestCase {
    private var namespace = MongoNamespace.init(databaseName: ObjectId().description,
                                                collectionName: ObjectId().description)
    private let docId = ObjectId()
    private lazy var document = ["_id": docId,
                                 "foo": 42,
                                 "bar": "baz"] as Document
    private let writePending = false

    func testTransform() {
        struct TestTransform: Codable {
            let _id: ObjectId
            let foo: Int
            let bar: String
        }
        let originalChangeEvent = ChangeEvent<Document>.init(
            id: Document(),
            operationType: .insert,
            fullDocument: ["_id": docId, "foo": 42, "bar": "baz"] as Document,
            ns: namespace,
            documentKey: ["_id": docId] as Document,
            updateDescription: nil,
            hasUncommittedWrites: writePending)
        let transformedChangeEvent: ChangeEvent<TestTransform> =
            ChangeEvent<TestTransform>.transform(changeEvent: originalChangeEvent)

        XCTAssertEqual(originalChangeEvent.id, transformedChangeEvent.id)
        XCTAssertEqual(originalChangeEvent.operationType, transformedChangeEvent.operationType)
        XCTAssertEqual(originalChangeEvent.fullDocument?["foo"] as? Int, transformedChangeEvent.fullDocument?.foo)
        XCTAssertEqual(originalChangeEvent.fullDocument?["bar"] as? String, transformedChangeEvent.fullDocument?.bar)
        XCTAssertEqual(originalChangeEvent.fullDocument?["_id"] as? ObjectId, transformedChangeEvent.fullDocument?._id)
        XCTAssertEqual(originalChangeEvent.ns, transformedChangeEvent.ns)
        XCTAssertEqual(originalChangeEvent.documentKey, transformedChangeEvent.documentKey)
        XCTAssertNil(transformedChangeEvent.updateDescription)
        XCTAssertEqual(originalChangeEvent.hasUncommittedWrites, transformedChangeEvent.hasUncommittedWrites)
    }

    func testChangeEventForLocalInsert() {
        let expectedLocalInsertEvent = ChangeEvent<Document>.init(
            id: Document(),
            operationType: .insert,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalInsertEvent = ChangeEvent<Document>.changeEventForLocalInsert(namespace: namespace,
                                                                                     document: document,
                                                                                     writePending: writePending)
        XCTAssertEqual(expectedLocalInsertEvent, actualLocalInsertEvent)
    }

    func testChangeEventForLocalReplace() {
        let expectedLocalReplaceEvent = ChangeEvent<Document>(
            id: Document(),
            operationType: .replace,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalReplaceEvent = ChangeEvent<Document>.changeEventForLocalReplace(namespace: namespace, documentId: docId, document: document, writePending: writePending)

        XCTAssertEqual(expectedLocalReplaceEvent, actualLocalReplaceEvent)
    }

    func testChangeEventForLocalUpdate() {
        let expectedLocalUpdateEvent = ChangeEvent<Document>(
            id: Document(),
            operationType: .update,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: UpdateDescription.init(updatedFields: ["foo": 42,
                                                                      "bar": "baz"],
                                                      removedFields: []),
            hasUncommittedWrites: writePending)

        let actualLocalUpdateEvent = ChangeEvent<Document>.changeEventForLocalUpdate(
            namespace: namespace,
            documentId: docId,
            update: UpdateDescription.init(updatedFields: ["foo": 42, "bar": "baz"], removedFields: []),
            fullDocumentAfterUpdate: document,
            writePending: writePending)

        XCTAssertEqual(expectedLocalUpdateEvent, actualLocalUpdateEvent)
    }

    func testChangeEventForLocalDelete() {
        let expectedLocalDeleteEvent = ChangeEvent<Document>(
            id: Document(),
            operationType: .delete,
            fullDocument: nil,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalDeleteEvent = ChangeEvent<Document>.changeEventForLocalDelete(namespace: namespace,
                                                                                     documentId: docId,
                                                                                     writePending: writePending)

        XCTAssertEqual(expectedLocalDeleteEvent, actualLocalDeleteEvent)
    }
}
