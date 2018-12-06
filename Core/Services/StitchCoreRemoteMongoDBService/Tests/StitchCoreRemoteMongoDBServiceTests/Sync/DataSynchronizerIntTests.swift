import Foundation
import StitchCoreSDK
import StitchCoreSDKMocks
import XCTest
import MongoSwift
import mongoc
@testable import StitchCoreRemoteMongoDBService

class DataSynchronizerUnitTests: XCMongoMobileTestCase {
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
    func testDeleteOne() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))


        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document

        _ = try dataSynchronizer.insertMany(documents: [doc1, doc2],
                                            in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        var deleteResult = try dataSynchronizer.deleteOne(filter: ["hello": "world"], options: nil, in: namespace)
        XCTAssertEqual(1, deleteResult?.deletedCount)

        XCTAssertEqual(1, try dataSynchronizer.count(in: namespace))
        XCTAssertEqual(0, try dataSynchronizer.count(filter: ["hello": "world"], options: nil, in: namespace))

        deleteResult = try dataSynchronizer.deleteOne(filter: [], options: nil, in: namespace)
        XCTAssertEqual(1, deleteResult?.deletedCount)
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))

        deleteResult = try dataSynchronizer.deleteOne(filter: [], options: nil, in: namespace)
        XCTAssertEqual(0, deleteResult?.deletedCount)
    }

    // TODO: STITCH-2215: This is an integration test and
    // should be moved upstream to `Sync` within RemoteMongoClientIntTests.
    // This will be possible after configuration is configured.
    func testDeleteMany() throws {
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventListener: TestEventListener(),
                                   errorListener: TestErrorListener())
        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))


        let doc1 = ["hello": "world", "a": "b"] as Document
        let doc2 = ["goodbye": "world", "a": "b"] as Document

        _ = try dataSynchronizer.insertMany(documents: [doc1, doc2],
                                            in: namespace)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))

        var deleteResult = try dataSynchronizer.deleteMany(filter: ["a": "c"], options: nil, in: namespace)
        XCTAssertEqual(0, deleteResult?.deletedCount)

        XCTAssertEqual(2, try dataSynchronizer.count(in: namespace))


        deleteResult = try dataSynchronizer.deleteMany(filter: ["a": "b"], options: nil, in: namespace)
        XCTAssertEqual(2, deleteResult?.deletedCount)

        XCTAssertEqual(0, try dataSynchronizer.count(in: namespace))
    }
}
