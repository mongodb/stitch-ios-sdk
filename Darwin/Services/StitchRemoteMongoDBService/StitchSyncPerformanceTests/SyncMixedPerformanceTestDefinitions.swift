//swiftlint:disable function_body_length
//swiftlint:disable type_body_length
import XCTest
import Foundation
import MongoSwift
@testable import StitchRemoteMongoDBService
@testable import StitchCoreRemoteMongoDBService

class SyncMixedPerformanceTestDefinitions {

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     * Test: Configure sync to sync, perform a local insert of numDoc / 2 documents
     *       Ensure there are numConflict conflicts, perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    static func testInitialSync(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        for conflictPercentage in SyncPerformanceTestUtils.conflictPercentages {
            performInitialSync(testHarness: testHarness, runId: runId, conflictPercentage: conflictPercentage)
        }
    }

    static func performInitialSync(testHarness: SyncPerformanceIntTestHarness,
                                   runId: ObjectId,
                                   conflictPercentage: Double) {
        let testName = "Mixed_InitialSync"
        var documentsIds: Set<AnyBSONValue> = []
        var documentsForLocalInsert: [Document]?
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                let numEach = numDocs / 2
                documentsIds = []
                documentsForLocalInsert = []

                // Insert documents into the remote database and save the inserted ids
                let remoteDocs = SyncPerformanceTestUtils.generateDocuments(numDoc: numEach, docSize: numEach)
                let joiner = ThrowingCallbackJoiner()
                ctx.coll.insertMany(remoteDocs, joiner.capture())
                guard let result: RemoteInsertManyResult = try joiner.value() else {
                    throw "Failed to insert \(numEach) documents of size \(docSize) to remote"
                }
                try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                    result.insertedIds.count,
                    numEach,
                    message: "RemoteInsert.insertedIds.count")
                for val in result.insertedIds {
                    documentsIds.insert(AnyBSONValue(val.value))
                }

                // Generate the documents to be inserted locally
                let numDocsWithConflicts = Int(Double(numEach) * conflictPercentage)
                var docs = SyncPerformanceTestUtils.generateDocuments(numDoc: numEach, docSize: docSize)
                for ind in 0 ..< numDocsWithConflicts {
                    docs[ind]["_id"] = result.insertedIds[Int64(ind)]
                }
                try SyncPerformanceTestUtils.assertIntsEqualOrThrow(docs.count, numEach, message: "docsForLocalInsert")
                documentsForLocalInsert = docs

        }, testDefinition: { ctx, numDocs, docSize in
            let numEach = numDocs / 2
            guard let documents = documentsForLocalInsert else {
                throw "Setup function did not return local document ids"
            }

            // Configure the data synchronizer
            try SyncPerformanceTestUtils.configureSync(ctx: ctx)

            // Perform local insert
            let joiner = ThrowingCallbackJoiner()
            ctx.coll.sync.insertMany(documents: documents, joiner.capture())
            guard let result: SyncInsertManyResult = try joiner.value() else {
                throw "Failed to insert \(numEach) documents of size \(docSize) to local"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                result.insertedIds.count,
                numEach,
                message: "LocalInsertInsert.insertedIds.count")
            for val in result.insertedIds {
                if let value = val.value {
                    documentsIds.insert(AnyBSONValue(value))
                }
            }

            // Make sure the inserts properly conflicted
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                documentsIds.count,
                Int(Double(numDocs) * (1.0 - (conflictPercentage / 2.0))),
                message: "Union of local and remote document ids")

            // Sync on all of the documentIds
            ctx.coll.sync.sync(ids: documentsIds.map { $0.value }, joiner.capture())
            let _: Any? = try joiner.value()

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            // Ensure the sync pass behaved properly
            let numConflicts = Int(Double(numDocs / 2) * conflictPercentage)
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs - numConflicts)
        })
    }

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     *         Perform a local insert of numDoc / 2 documents
     *         Configure sync(), perform sync pass, disconnect networkMonitor
     *         Ensure sync worked properly
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    static func testDisconnectReconnect(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "Mixed_DisconnectReconnect"

        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                let numEach = numDocs / 2

                // Insert the documents into the remote collection
                let remoteIds = try SyncPerformanceTestUtils.insertToRemote(
                    ctx: ctx,
                    numDocs:
                    numEach, docSize: docSize)

                // Insert the documents into the local collection
                let localIds = try SyncPerformanceTestUtils.insertToLocal(
                    ctx: ctx,
                    numDocs: numEach,
                    docSize: docSize)

                // Configure the data synchronizer
                try SyncPerformanceTestUtils.configureSync(ctx: ctx)

                // Sync on all of the ids
                let joiner = ThrowingCallbackJoiner()
                ctx.coll.sync.sync(ids: remoteIds, joiner.capture())
                let _: Any? = try joiner.value()
                ctx.coll.sync.sync(ids: localIds, joiner.capture())
                let _: Any? = try joiner.value()
                ctx.coll.sync.syncedIds(joiner.capture())
                guard let syncedIds: Set<AnyBSONValue> = try joiner.value() else {
                    throw "Could not unwrap syncedIds()"
                }
                try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                    syncedIds.count, numDocs, message: "SyncedIds.count")

                // Perform sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Disconnect the network monitor
                try SyncPerformanceTestUtils.disconnectNetworkAndWaitForStreams(ctx: ctx )
        }, testDefinition: { ctx, _, _ in

            // Reconnect the network monitor
            try SyncPerformanceTestUtils.connectNetworkAndWaitForStreams(ctx: ctx)
            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)
        }, afterEach: { ctx, numDocs, _ in
            // Verify that the test did indeed synchronize the updates locally
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)
        })
    }

    /*
     * Before: Perform remote insert of numDoc / 2 documents
     *         Perform a local insert of numDoc / 2 documents
     *         Configure sync(), perform sync pass
     *         Update numChangeEvents / 2 documents remotely
     *         Update numChangeEvents / 2 documents locally
     *              Where numConflicts docs are updates on the same documents
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly
     */
    static func testSyncPass(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        for changeEventPercentage in SyncPerformanceTestUtils.changeEventPercentages {
            for conflictPercentage in SyncPerformanceTestUtils.conflictPercentages {
                doSyncPass(testHarness: testHarness,
                           runId: runId,
                           changeEventPercentage: changeEventPercentage,
                           conflictPercentage: conflictPercentage)
            }
        }
    }

    private static func doSyncPass(testHarness: SyncPerformanceIntTestHarness,
                                   runId: ObjectId,
                                   changeEventPercentage: Double,
                                   conflictPercentage: Double) {
        let testName = "Mixed_SyncPass"

        var documentsIds: [BSONValue]?
        var updatedIds: Set<AnyBSONValue> = []
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                let numEach = numDocs / 2
                updatedIds = []

                // Insert the documents into the remote collection
                let remoteIds = try SyncPerformanceTestUtils.insertToRemote(
                    ctx: ctx,
                    numDocs:
                    numEach, docSize: docSize)

                // Insert the documents into the local collection
                let localIds = try SyncPerformanceTestUtils.insertToLocal(
                    ctx: ctx,
                    numDocs: numEach,
                    docSize: docSize)

                // Configure the data synchronizer
                try SyncPerformanceTestUtils.configureSync(ctx: ctx)

                // Sync on all of the ids
                let joiner = ThrowingCallbackJoiner()
                ctx.coll.sync.sync(ids: remoteIds, joiner.capture())
                let _: Any? = try joiner.value()
                ctx.coll.sync.sync(ids: localIds, joiner.capture())
                let _: Any? = try joiner.value()
                ctx.coll.sync.syncedIds(joiner.capture())
                guard let syncedIds: Set<AnyBSONValue> = try joiner.value() else {
                    throw "Could not unwrap syncedIds()"
                }
                try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                    syncedIds.count, numDocs, message: "SyncedIds.count")

                // Perform sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Shuffle all the synced document ids
                let shuffledIds = syncedIds.shuffled().map { $0.value }

                // Remotely update the desired percentage of documents
                let numRemoteUpdates = Int(Double(numEach) * changeEventPercentage)
                try SyncPerformanceTestUtils.performRemoteUpdate(
                    ctx: ctx,
                    ids: [BSONValue](shuffledIds.prefix(numRemoteUpdates)))
                shuffledIds.prefix(numRemoteUpdates).forEach {
                    updatedIds.insert(AnyBSONValue($0))
                }

                documentsIds = shuffledIds

        }, testDefinition: { ctx, numDocs, _ in
            // Get the number of updates and conflicts
            let numEach = numDocs / 2
            let numRemoteUpdates = Int(Double(numEach) * changeEventPercentage)
            let numConflicts = Int(Double(numRemoteUpdates) * conflictPercentage)

            guard let ids = documentsIds else {
                throw "Could not unwrap document ids in testDefinition"
            }

            // Perform conflicting local updates
            try SyncPerformanceTestUtils.performLocalUpdate(ctx: ctx, ids: [BSONValue](ids.prefix(numConflicts)))
            ids.prefix(numConflicts).forEach {
                updatedIds.insert(AnyBSONValue($0))
            }

            // Performing non-conflicting local updates
            try SyncPerformanceTestUtils.performLocalUpdate(
                ctx: ctx,
                ids: [BSONValue](ids.suffix(numRemoteUpdates - numConflicts)),
                additionalCount: numConflicts)
            ids.suffix(numRemoteUpdates - numConflicts).forEach {
                updatedIds.insert(AnyBSONValue($0))
            }

            testHarness.logMessage(message: "Set of Updated Ids: \(updatedIds.count)")

            let joiner = ThrowingCallbackJoiner()
            // This is just here for testing
            ctx.coll.aggregate([
                ["$group": ["_id": "$newField", "count": ["$sum": 1] as Document] as Document] as Document
                ]).toArray(joiner.capture())
            guard let arr: [Document] = try joiner.value() else {
                throw "Error"
            }
            for doc in arr {
                testHarness.logMessage(message: "Remote: \(doc.canonicalExtendedJSON)")
            }

            let cursor = ctx.coll.sync.aggregate([
                ["$group": ["_id": "$newField", "count": ["$sum": 1] as Document] as Document] as Document
            ])

            cursor!.forEach {
                testHarness.logMessage(message: "Local: \($0.canonicalExtendedJSON)")
            }

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            let numEach = numDocs / 2
            let numRemoteUpdates = Int(Double(numEach) * changeEventPercentage)
            let numConflicts = Int(Double(numRemoteUpdates) * conflictPercentage)
            let numLocalUpdates = numRemoteUpdates - numConflicts

            testHarness.logMessage(message: "NumUpdates: \(numRemoteUpdates)")
            testHarness.logMessage(message: "NumConflicts: \(numConflicts)")

            // Verify that the local and remote collections have the right number of documents
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

            let joiner2 = ThrowingCallbackJoiner()
            ctx.coll.aggregate([
                ["$group": ["_id": "$newField", "count": ["$sum": 1] as Document] as Document] as Document
            ]).toArray(joiner2.capture())
            guard let arr: [Document] = try joiner2.value() else {
                throw "not workign"
            }
            for doc in arr {
                testHarness.logMessage(message: doc.canonicalExtendedJSON)
            }

            // Verify that the updates were applied locally.
            // Both the local and remote should have
            //      numRemoteUpdates documents with {newField: "remote"}
            //      numLocalUpdates documents with {newField: "local"}
            let joiner = ThrowingCallbackJoiner()
            ctx.coll.count(["newField": "remote"], options: nil, joiner.capture())
            guard let remoteRemoteCount: Int = try joiner.value() else {
                throw "Remote Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                remoteRemoteCount, numRemoteUpdates,
                message: "Number of remotely updated documents in remote collection")

            ctx.coll.count(["newField": "local"], options: nil, joiner.capture())
            guard let remoteLocalCount: Int = try joiner.value() else {
                throw "Remote Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                remoteLocalCount, numLocalUpdates,
                message: "Number of locally updated documents in remote collection")

            ctx.coll.sync.count(filter: ["newField": "remote"], options: nil, joiner.capture())
            guard let localRemoteCount: Int = try joiner.value() else {
                throw "Local Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                localRemoteCount, numRemoteUpdates,
                message: "Number of remotely updated documents in local collection")

            ctx.coll.sync.count(filter: ["newField": "local"], options: nil, joiner.capture())
            guard let localLocalCount: Int = try joiner.value() else {
                throw "Local Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                localLocalCount, numRemoteUpdates,
                message: "Number of locally updated documents in local collection")
        }, extraFields: [
            "percentageChangeEvent": changeEventPercentage,
            "percentageConflict": conflictPercentage]
        )
    }
}
