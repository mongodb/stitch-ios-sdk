import Foundation
import StitchCoreSDK
import StitchCoreSDKMocks
import XCTest
import MongoSwift
import mongoc
@testable import StitchCoreRemoteMongoDBService

class DataSynchronizerIntTests: XCMongoMobileTestCase {
    lazy var collection = try! localCollection(for: MongoNamespace.init(
        databaseName: DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace),
        collectionName: namespace.collectionName))

    func testStart_Stop() {
        XCTAssertFalse(dataSynchronizer.isRunning)

        // dataSynchronizer should not start until configured
        dataSynchronizer.start()
        XCTAssertFalse(dataSynchronizer.isRunning)

        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())

        dataSynchronizer.start()
        XCTAssertTrue(dataSynchronizer.isRunning)

        dataSynchronizer.stop()
        XCTAssertFalse(dataSynchronizer.isRunning)
    }

    func testSync_SyncedIds_Desync() {
        let ids = [ObjectId(), ObjectId()]

        dataSynchronizer.sync(ids: ids, in: namespace)
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       dataSynchronizer.syncedIds(in: namespace))

        dataSynchronizer.desync(ids: ids, in: namespace)
        XCTAssertEqual(Set(),
                       dataSynchronizer.syncedIds(in: namespace))
    }

    func testConfigure_ReloadConfig() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertTrue(dataSynchronizer.isRunning)

        try dataSynchronizer.reloadConfig()

        XCTAssertFalse(dataSynchronizer.isRunning)
    }

    func testCount() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try collection.insertMany([doc1, doc2])

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        try collection.deleteMany(Document())

        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))
    }

    func testFind() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document
        try collection.insertMany([doc1, doc2])

        let cursor: MongoCursor<Document> =
            try dataSynchronizer.find(filter: ["hello": "computer"], options: nil, in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        let actualDoc = cursor.next()

        XCTAssertEqual("b", actualDoc?["a"] as? String)
        XCTAssertNotNil(actualDoc?["_id"])
        XCTAssertEqual("computer", actualDoc?["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testAggregate() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try collection.insertMany([doc1, doc2])

        let cursor = try dataSynchronizer.aggregate(
            pipeline: [
                ["$project": ["_id": 0, "a": 0] as Document],
                ["$match": ["hello": "computer"] as Document]
            ],
            options: nil,
            in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        let actualDoc = cursor.next()

        XCTAssertNil(actualDoc?["a"])
        XCTAssertNil(actualDoc?["_id"])
        XCTAssertEqual("computer", actualDoc?["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testInsertOne() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b", DOCUMENT_VERSION_FIELD: "naughty"] as Document

        let insertOneResult = try dataSynchronizer.insertOne(document: doc1,
                                                              in: namespace)

        let cursor: MongoCursor<Document> =
            try dataSynchronizer.find(filter: ["_id": insertOneResult?.insertedId],
                                      options: nil,
                                      in: namespace)

        XCTAssertEqual(1, try dataSynchronizer.count(in: namespace))

        guard let actualDoc = cursor.next() else {
            XCTFail("doc was not inserted")
            return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertOneResult?.insertedId ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(DOCUMENT_VERSION_FIELD))
        XCTAssertNil(cursor.next())
    }

    func testInsertMany() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        let insertManyResult = try dataSynchronizer.insertMany(documents: [doc1, doc2],
                                                               in: namespace)

        let cursor: MongoCursor<Document> =
            try dataSynchronizer.find(filter: ["_id":
                [ "$in": insertManyResult?.insertedIds.values.map { $0 } ] as Document
            ],
                                      options: nil,
                                      in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        guard let actualDoc = cursor.next() else {
            XCTFail("doc was not inserted")
            return
        }

        XCTAssertEqual("b", actualDoc?["a"] as? String)
        XCTAssert(bsonEquals(insertManyResult?.insertedIds[0] ?? nil, actualDoc?["_id"]))
        XCTAssertEqual("world", actualDoc?["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(DOCUMENT_VERSION_FIELD))
        XCTAssertNotNil(cursor.next())
    }

    func testUpdateOne() throws {

    }
}
