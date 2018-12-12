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

    func testRecoverUpdateNoPendingWrite() throws {
        try replaceDataSynchronizer(deinitializing: false)
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())

        let originalTestDoc = ["count": 1] as Document
        let insertResult = try dataSynchronizer.insertOne(document: originalTestDoc, in: namespace)
        let insertedId = insertResult!.insertedId!

        XCTAssertTrue(try isUndoCollectionEmpty())

        let expectedTestDoc = [
            "_id": insertedId,
            "count": 1
        ] as Document

        XCTAssertEqual(
            expectedTestDoc,
            try localCollection().find(
                ["_id": insertedId],
                options: nil
            ).next()
        )

        _ = dataSynchronizer.doSyncPass()
        XCTAssertEqual(expectedTestDoc, try dataSynchronizer.find(in: namespace).next())

        // simulate a failure case where an update started, but did not get pending writes set
        try localCollection().updateOne(
            filter: ["_id": insertedId],
            update: ["$set": ["oops": true] as Document]
        )

        print("starting second data synchronizer replace")
        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [expectedTestDoc]
        )

        print("THIS SHOULD NOT BE GETTING PRINTED!!!")

        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())

        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the update got rolled back
        XCTAssertEqual(
            expectedTestDoc,
            try dataSynchronizer.find(
                filter: ["_id": insertedId],
                options: nil,
                in: namespace
            ).next()
        )
    }
}
