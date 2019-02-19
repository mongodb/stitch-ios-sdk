// swiftlint:disable function_body_length
// swiftlint:disable nesting
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

    private func compare<T: Codable>(expectedChangeEvent: ChangeEvent<T>,
                                     to actualChangeEvent: ChangeEvent<T>) throws {
        XCTAssertTrue(bsonEquals(expectedChangeEvent.id.value, actualChangeEvent.id.value))
        XCTAssertEqual(expectedChangeEvent.operationType, actualChangeEvent.operationType)
        XCTAssertEqual(try BSONEncoder().encode(expectedChangeEvent.fullDocument),
                       try BSONEncoder().encode(actualChangeEvent.fullDocument))
        XCTAssertEqual(expectedChangeEvent.ns, actualChangeEvent.ns)
        XCTAssertEqual(expectedChangeEvent.documentKey, actualChangeEvent.documentKey)
        XCTAssertEqual(expectedChangeEvent.updateDescription?.asUpdateDocument,
                       actualChangeEvent.updateDescription?.asUpdateDocument)
        XCTAssertEqual(expectedChangeEvent.hasUncommittedWrites, actualChangeEvent.hasUncommittedWrites)
    }

    func testTransform() throws {
        struct TestTransform: Codable {
            let _id: ObjectId
            let foo: Int
            let bar: String
        }
        let originalChangeEvent = ChangeEvent<Document>.init(
            id: AnyBSONValue(Document()),
            operationType: .insert,
            fullDocument: ["_id": docId, "foo": 42, "bar": "baz"] as Document,
            ns: namespace,
            documentKey: ["_id": docId] as Document,
            updateDescription: nil,
            hasUncommittedWrites: writePending)
        let transformedChangeEvent: ChangeEvent<TestTransform> =
            try ChangeEvents.transform(changeEvent: originalChangeEvent)

        XCTAssertTrue(bsonEquals(originalChangeEvent.id.value, transformedChangeEvent.id.value))
        XCTAssertEqual(originalChangeEvent.operationType, transformedChangeEvent.operationType)
        XCTAssertEqual(originalChangeEvent.fullDocument?["foo"] as? Int, transformedChangeEvent.fullDocument?.foo)
        XCTAssertEqual(originalChangeEvent.fullDocument?["bar"] as? String, transformedChangeEvent.fullDocument?.bar)
        XCTAssertEqual(originalChangeEvent.fullDocument?["_id"] as? ObjectId, transformedChangeEvent.fullDocument?._id)
        XCTAssertEqual(originalChangeEvent.ns, transformedChangeEvent.ns)
        XCTAssertEqual(originalChangeEvent.documentKey, transformedChangeEvent.documentKey)
        XCTAssertNil(transformedChangeEvent.updateDescription)
        XCTAssertEqual(originalChangeEvent.hasUncommittedWrites, transformedChangeEvent.hasUncommittedWrites)
    }

    func testChangeEventForLocalInsert() throws {
        let expectedLocalInsertEvent = ChangeEvent<Document>.init(
            id: AnyBSONValue(Document()),
            operationType: .insert,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalInsertEvent = ChangeEvents.changeEventForLocalInsert(namespace: namespace,
                                                                                     document: document,
                                                                                     documentId: docId,
                                                                                     writePending: writePending)
        try compare(expectedChangeEvent: expectedLocalInsertEvent, to: actualLocalInsertEvent)
    }

    func testChangeEventForLocalReplace() throws {
        let expectedLocalReplaceEvent = ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .replace,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalReplaceEvent = ChangeEvents.changeEventForLocalReplace(
            namespace: namespace, documentId: docId, document: document, writePending: writePending
        )

        try compare(expectedChangeEvent: expectedLocalReplaceEvent, to: actualLocalReplaceEvent)
    }

    func testChangeEventForLocalUpdate() throws {
        let expectedLocalUpdateEvent = ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .update,
            fullDocument: document,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: UpdateDescription.init(updatedFields: ["foo": 42,
                                                                      "bar": "baz"],
                                                      removedFields: []),
            hasUncommittedWrites: writePending)

        let actualLocalUpdateEvent = ChangeEvents.changeEventForLocalUpdate(
            namespace: namespace,
            documentId: docId,
            update: UpdateDescription.init(updatedFields: ["foo": 42, "bar": "baz"], removedFields: []),
            fullDocumentAfterUpdate: document,
            writePending: writePending)

        try compare(expectedChangeEvent: expectedLocalUpdateEvent,
                    to: actualLocalUpdateEvent)
    }

    func testChangeEventForLocalDelete() throws {
        let expectedLocalDeleteEvent = ChangeEvent<Document>(
            id: AnyBSONValue(Document()),
            operationType: .delete,
            fullDocument: nil,
            ns: namespace,
            documentKey: ["_id": docId],
            updateDescription: nil,
            hasUncommittedWrites: writePending)

        let actualLocalDeleteEvent = ChangeEvents.changeEventForLocalDelete(namespace: namespace,
                                                                                     documentId: docId,
                                                                                     writePending: writePending)

        try compare(expectedChangeEvent: expectedLocalDeleteEvent,
                    to: actualLocalDeleteEvent)
    }

    func testRoundTrip() throws {
        let id = ObjectId()
        let documentKey = ObjectId()
        let insertEvent = try BSONDecoder().decode(ChangeEvent<Document>.self, from: """
        {
           "_id" : { "$oid": "\(id.oid)" },
           "operationType" : "insert",
           "fullDocument" : { "foo": "bar" },
           "ns" : {
              "db" : "database",
              "coll" : "collection"
           },
           "documentKey" : { "_id" : "\(documentKey.oid)" },
           "updateDescription" : null
        }
        """)

        var expectedChangeEvent = ChangeEvent<Document>.init(
            id: AnyBSONValue(id),
            operationType: .insert,
            fullDocument: ["foo": "bar"],
            ns: MongoNamespace.init(databaseName: "database", collectionName: "collection"),
            documentKey: ["_id": documentKey.oid],
            updateDescription: nil,
            hasUncommittedWrites: false)

        try compare(expectedChangeEvent: expectedChangeEvent, to: insertEvent)

        let unknownEvent = try BSONDecoder().decode(ChangeEvent<Document>.self, from: """
            {
            "_id" : { "$oid": "\(id.oid)" },
            "operationType" : "__lolwut__",
            "fullDocument" : { "foo": "bar" },
            "ns" : {
            "db" : "database",
            "coll" : "collection"
            },
            "documentKey" : { "_id" : "\(documentKey.oid)" },
            "updateDescription" : null
            }
        """)

        expectedChangeEvent = ChangeEvent<Document>.init(
            id: AnyBSONValue(id),
            operationType: .unknown,
            fullDocument: ["foo": "bar"],
            ns: MongoNamespace.init(databaseName: "database", collectionName: "collection"),
            documentKey: ["_id": documentKey.oid],
            updateDescription: nil,
            hasUncommittedWrites: false)

        try compare(expectedChangeEvent: expectedChangeEvent, to: unknownEvent)
    }
}
