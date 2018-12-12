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

    private func prepareRecoveryLogicTest() throws -> (insertedId: BSONValue, insertedDoc: Document) {
        // replace test context's DataSynchronizer with a non-deinitializing datasynchronizer so we don't drop our
        // config database when creating a new data synchronizer to test the recovery logic
        try replaceDataSynchronizer(deinitializing: false)
        dataSynchronizer.configure(namespace: namespace,
                                   conflictHandler: TestConflictHandler(),
                                   changeEventDelegate: TestEventDelegate(),
                                   errorListener: TestErrorListener())

        // insert a test document
        let originalTestDoc = ["count": 1] as Document
        let insertResult = try dataSynchronizer.insertOne(document: originalTestDoc, in: namespace)
        let insertedId = insertResult!.insertedId!
        let insertedDoc: Document = try dataSynchronizer.find(in: namespace).next()!


        // ensure that our insert did not leak anything to the undo collection
        XCTAssertTrue(try isUndoCollectionEmpty())

        // do a sync pass and make sure our document is still there
        _ = dataSynchronizer.doSyncPass()
        XCTAssertEqual(insertedDoc, try dataSynchronizer.find(in: namespace).next())

        // return the inserted document and its _id
        return (insertedId, insertedDoc)
    }

    func testRecoverUpdateNoPendingWrite() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a failure case where an update started, but did not get pending writes set
        try localCollection().updateOne(
            filter: ["_id": insertedId],
            update: ["$set": ["oops": true] as Document]
        )

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [insertedDoc]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the update got rolled back
        XCTAssertEqual(
            insertedDoc,
            try dataSynchronizer.find(
                filter: ["_id": insertedId],
                options: nil,
                in: namespace
            ).next()
        )
    }

    func testRecoverUpdateWithPendingWrite() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a failure case where an update started and got pending writes set, but the undo
        // document still exists
        try localCollection().updateOne(
            filter: ["_id": insertedId],
            update: ["$set": ["oops": true] as Document]
        )

        var expectedNewDoc = insertedDoc
        expectedNewDoc["oops"] = true

        try setPendingWrites(
            forDocumentId: insertedId,
            event: ChangeEvent<Document>.changeEventForLocalUpdate(
                namespace: namespace,
                documentId: insertedId,
                update: expectedNewDoc.diff(otherDocument: insertedDoc),
                fullDocumentAfterUpdate: expectedNewDoc,
                writePending: true
            )
        )

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [insertedDoc]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the update did not get rolled back, since we set pending writes
        XCTAssertEqual(
            expectedNewDoc,
            try dataSynchronizer.find(
                filter: ["_id": insertedId],
                options: nil,
                in: namespace
                ).next()
        )
    }

    func testRecoverDeleteNoPendingWrite() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a failure case where a delete started, but did not get pending writes set
        try localCollection().deleteOne(["_id": insertedId])

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [insertedDoc]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the delete got rolled back
        XCTAssertEqual(insertedDoc, try dataSynchronizer.find(in: namespace).next())
    }

    func testRecoverDeleteWithPendingWrite() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a failure case where a delete started and got pending writes, but the undo
        // document still exists
        try localCollection().deleteOne(["_id": insertedId])

        try setPendingWrites(
            forDocumentId: insertedId,
            event: ChangeEvent<Document>.changeEventForLocalDelete(
                namespace: namespace,
                documentId: insertedId,
                writePending: true
        ))

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [insertedDoc]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the delete did not get rolled back, since we already set pending writes
        XCTAssertNil(try dataSynchronizer.find(in: namespace).next() as Document?)
    }

    func testRecoverUpdateOldPendingWrite() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a failure case where an update started, but did not get pending writes set, and
        // a previous completed update event is pending but uncommitted
        _ = try dataSynchronizer.updateOne(
            filter: ["_id": insertedId],
            update: ["$inc": ["count": 1] as Document],
            options: nil,
            in: namespace
        )
        var expectedTestDoc = insertedDoc
        expectedTestDoc["count"] = 2

        // don't do a sync pass so that we have a pending write set with that incremented count

        try localCollection().updateOne(
            filter: ["_id": insertedId],
            update: ["$set": ["oops": true] as Document]
        )

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [insertedDoc]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // assert that the update got rolled back to the state of the previous completed update
        // that had uncommitted pending writes
        XCTAssertEqual(expectedTestDoc, try dataSynchronizer.find(in: namespace).next())
    }

    func testRecoverUnsychronizedDocument() throws {
        let (insertedId, insertedDoc) = try prepareRecoveryLogicTest()

        // simulate a pathological case where a user tries to insert arbitrary documents into the
        // undo collection
        let fakeRecoveryDocumentId = ObjectId()
        let fakeRecoveryDocument = [
            "_id": fakeRecoveryDocumentId,
            "hello collection": "my old friend"
        ] as Document

        try replaceDataSynchronizer(
            deinitializing: true,
            withUndoDocuments: [fakeRecoveryDocument]
        )

        // ensure that no undo documents remain after the recovery pass is completed
        XCTAssertTrue(try isUndoCollectionEmpty())

        // ensure that undo documents that represent unsynchronized documents don't exist in the
        // local collection after a recovery pass
        XCTAssertNil(try dataSynchronizer.find(
            filter: ["_id": fakeRecoveryDocumentId],
            options: nil,
            in: namespace
        ).next() as Document?)

        // but that our originally inserted document remains intact
        XCTAssertEqual(insertedDoc, try dataSynchronizer.find(
            filter: ["_id": insertedId],
            options: nil,
            in: namespace
            ).next()
        )
    }
}
