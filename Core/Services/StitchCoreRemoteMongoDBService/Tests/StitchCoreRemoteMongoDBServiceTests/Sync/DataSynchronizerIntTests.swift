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
                                   changeEventDelegate: TestEventDelegate(),
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
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())
        XCTAssertTrue(dataSynchronizer.isRunning)

        try dataSynchronizer.reloadConfig()

        XCTAssertFalse(dataSynchronizer.isRunning)
    }

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testCount() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try collection.insertMany([doc1, doc2])

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        try collection.deleteMany(Document())

        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))
    }

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testFind() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
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

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testAggregate() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
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

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testInsertOne() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
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

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testInsertMany() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
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

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssert(bsonEquals(insertManyResult?.insertedIds[0] ?? nil, actualDoc["_id"]))
        XCTAssertEqual("world", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(DOCUMENT_VERSION_FIELD))
        XCTAssertNotNil(cursor.next())
    }

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testUpdateOne() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b", DOCUMENT_VERSION_FIELD: "naughty"] as Document

        guard let insertedId = try dataSynchronizer.updateOne(
            filter: doc1,
            update: doc1,
            options: UpdateOptions(upsert: true),
            in: namespace)?.upsertedId?.value else {
            XCTFail("upsert failed")
            return
        }

        let updateResult = try dataSynchronizer.updateOne(filter: ["_id": insertedId],
                                                          update: ["$set": ["hello": "goodbye"] as Document],
                                                          options: nil,
                                                          in: namespace)

        XCTAssertEqual(updateResult?.matchedCount, 1)
        XCTAssertEqual(updateResult?.modifiedCount, 1)
        XCTAssertEqual(updateResult?.upsertedCount, 0)
        XCTAssertNil(updateResult?.upsertedId)
        let cursor: MongoCursor<Document> =
            try dataSynchronizer.find(filter: ["_id": insertedId],
                                      options: nil,
                                      in: namespace)

        XCTAssertEqual(1, try dataSynchronizer.count(in: namespace))

        guard let actualDoc = cursor.next() else {
            XCTFail("doc was not inserted")
            return
        }

        XCTAssertEqual("b", actualDoc["a"] as? String)
        XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
        XCTAssertFalse(actualDoc.hasKey(DOCUMENT_VERSION_FIELD))
        XCTAssertNil(cursor.next())
    }

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testUpdateMany() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        let doc1 = ["hello": "world", "a": "b", DOCUMENT_VERSION_FIELD: "naughty"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        guard let insertedIds: [BSONValue] = try dataSynchronizer
            .insertMany(documents: [doc1, doc2],
                        in: namespace)?
            .insertedIds.compactMap({ $0.value }) else {
            XCTFail("insert failed")
            return
        }

        let updateResult = try dataSynchronizer.updateMany(filter: ["_id": ["$in": insertedIds] as Document],
                                                          update: ["$set": ["hello": "goodbye"] as Document],
                                                          options: nil,
                                                          in: namespace)

        XCTAssertEqual(updateResult?.matchedCount, 2)
        XCTAssertEqual(updateResult?.modifiedCount, 2)
        XCTAssertEqual(updateResult?.upsertedCount, 0)
        XCTAssertNil(updateResult?.upsertedId)
        let cursor: MongoCursor<Document> =
            try dataSynchronizer.find(filter: ["_id": ["$in": insertedIds] as Document],
                                      options: nil,
                                      in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        cursor.forEach { actualDoc in
            XCTAssertEqual("b", actualDoc["a"] as? String)
            XCTAssertEqual("goodbye", actualDoc["hello"] as? String)
            XCTAssertFalse(actualDoc.hasKey(DOCUMENT_VERSION_FIELD))
        }
    }
}
