import Foundation
import MongoSwift
import XCTest
@testable import StitchCoreRemoteMongoDBService
class CoreSyncUnitTests: XCMongoMobileTestCase {
    private lazy var coreSync = CoreSync<Document>.init(namespace: namespace,
                                                        dataSynchronizer: dataSynchronizer)
    lazy var collection = try! localCollection(for: MongoNamespace.init(
        databaseName: DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace),
        collectionName: namespace.collectionName))

    override func tearDown() {
        try? localClient.db("sync_config" + instanceKey.oid).drop()
    }

    func testConfigure() {
        XCTAssertFalse(dataSynchronizer.isConfigured)
        coreSync.configure(conflictHandler: TestConflictHandler(),
                           changeEventListener: TestEventListener(),
                           errorListener: TestErrorListener())
        XCTAssertTrue(dataSynchronizer.isConfigured)
        XCTAssertTrue(dataSynchronizer.isRunning)
    }

    func testSync_SyncedIds_Desync() {
        let ids = [ObjectId(), ObjectId()]

        coreSync.sync(ids: ids)
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       dataSynchronizer.syncedIds(in: namespace))
        XCTAssertEqual(Set(ids.map { HashableBSONValue($0) }),
                       coreSync.syncedIds)

        coreSync.desync(ids: ids)
        XCTAssertEqual(Set(),
                       dataSynchronizer.syncedIds(in: namespace))
        XCTAssertEqual(Set(),
                       coreSync.syncedIds)
    }

    func testCount() throws {
        XCTAssertEqual(0, try coreSync.count())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try localClient.db(DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace))
            .collection(namespace.collectionName, withType: Document.self).insertMany([doc1, doc2])

        XCTAssertEqual(2, try coreSync.count())

        try localClient.db(DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace))
            .collection(namespace.collectionName, withType: Document.self).deleteMany(Document())

        XCTAssertEqual(0, try coreSync.count())
    }

    func testFind() throws {
        XCTAssertEqual(0, try coreSync.count())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try localClient.db(DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace))
            .collection(namespace.collectionName, withType: Document.self).insertMany([doc1, doc2])

        let cursor: MongoCursor<Document> =
            try coreSync.find(filter: ["hello": "computer"])

        XCTAssertEqual(2, try coreSync.count())

        let actualDoc = cursor.next()

        XCTAssertEqual("b", actualDoc?["a"] as? String)
        XCTAssertNotNil(actualDoc?["_id"])
        XCTAssertEqual("computer", actualDoc?["hello"] as? String)

        XCTAssertNil(cursor.next())
    }

    func testAggregate() throws {
        XCTAssertEqual(0, try coreSync.count())

        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["hello": "computer", "a": "b"] as Document

        try localClient.db(DataSynchronizer.localUserDBName(withInstanceKey: instanceKey.oid, for: namespace))
            .collection(namespace.collectionName, withType: Document.self).insertMany([doc1, doc2])

        let cursor = try coreSync.aggregate(
            pipeline: [
                ["$project": ["_id": 0, "a": 0] as Document],
                ["$match": ["hello": "computer"] as Document]
            ])

        XCTAssertEqual(2, try coreSync.count())

        let actualDoc = cursor.next()

        XCTAssertNil(actualDoc?["a"])
        XCTAssertNil(actualDoc?["_id"])
        XCTAssertEqual("computer", actualDoc?["hello"] as? String)

        XCTAssertNil(cursor.next())
    }
}
