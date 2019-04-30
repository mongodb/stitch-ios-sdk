//swiftlint:disable function_body_length
import XCTest
import Foundation
import MongoSwift
@testable import StitchRemoteMongoDBService
@testable import StitchCoreRemoteMongoDBService

class SyncR2LOnlyPerformanceTestDefinitions {

    /*
     * Before: Perform remote insert of numDoc documents
     * Test: Configure sync to sync on the inserted docs and perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    static func testInitialSync(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "R2L_InitialSync"
        var documentIdsForTest: [BSONValue]?
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Insert documents into the remote database and save the inserted ids
                documentIdsForTest = try SyncPerformanceTestUtils.insertToRemote(ctx: ctx,
                                                                                 numDocs: numDocs,
                                                                                 docSize: docSize)
        }, testDefinition: { ctx, _, _ in
            guard let docIds = documentIdsForTest else {
                throw "Setup function did not return document ids"
            }

            // Configure the data synchronizer
            let joiner = ThrowingCallbackJoiner()
            ctx.coll.sync.configure(
                conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                changeEventDelegate: nil,
                errorListener: { err, id in
                    harness.logMessage(message: "Sync Error with id (\(id ?? "nil")): \(err)")
            }, joiner.capture())
            let _: Any? = try joiner.value()

            // Call sync() on the given document ids
            ctx.coll.sync.sync(ids: docIds, joiner.capture())
            let _: Any? = try joiner.value()

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            // Ensure the sync pass behaved properly
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)
        })
    }

    /*
     * Before: Perform remote insert of numDoc documents, configure sync(), perform sync pass, disconnect networkMonitor
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    static func testDisconnectReconnect(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "R2L_DisconnectReconnect"

        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Insert the documents into the remote collection
                let docIds = try SyncPerformanceTestUtils.insertToRemote(ctx: ctx, numDocs: numDocs, docSize: docSize)

                // Configure the data synchronizer
                let joiner = ThrowingCallbackJoiner()
                ctx.coll.sync.configure(
                    conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                    changeEventDelegate: nil,
                    errorListener: { err, id in
                        harness.logMessage(message: "Sync Error with id (\(id ?? "nil")): \(err)")
                }, joiner.capture())
                let _: Any? = try joiner.value()

                // Sync on the ids
                ctx.coll.sync.sync(ids: docIds, joiner.capture())
                let _: Any? = try joiner.value()

                // Perform the sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Disconnect the network monitor and wait until all streams are closed (max 30 seconds)
                ctx.harness.networkMonitor.state = .disconnected
                var iters = 0
                while ctx.coll.sync.proxy.dataSynchronizer.allStreamsAreOpen {
                    iters += 1
                    if iters >= 1000 {
                        throw "Streams never closed"
                    }
                    Thread.sleep(forTimeInterval: 30.0 / 1000)
                }
        }, testDefinition: { ctx, _, _ in
            // Reconnect the network monitor
            ctx.harness.networkMonitor.state = .connected

            // Wait for the streams to open up
            var iters = 0
            while !ctx.coll.sync.proxy.dataSynchronizer.allStreamsAreOpen {
                iters += 1
                if iters >= 1000 {
                    throw "Streams never opened"
                }
                Thread.sleep(forTimeInterval: 30.0 / 1000)
            }

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)
        }, afterEach: { ctx, numDocs, _ in
            // Verify that the test did indeed synchronize the updates locally
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)
        })
    }

    /*
     * Before: Perform remote insert of numDoc documents, configure sync(), perform sync pass
     *         Then remote update numChangeEvent documents remotely, and numConflict documents locally
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly and that the local collection has received remote updates
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
        let testName = "R2L_SyncPass"

        var numRemoteDocsChanged: Int?
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Insert the documents into the remote collection
                var docIds = try SyncPerformanceTestUtils.insertToRemote(ctx: ctx, numDocs: numDocs, docSize: docSize)

                // Configure the data synchronizer
                let joiner = ThrowingCallbackJoiner()
                ctx.coll.sync.configure(
                    conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                    changeEventDelegate: nil,
                    errorListener: { err, id in
                        harness.logMessage(message: "Sync Error with id (\(id ?? "nil")): \(err)")
                }, joiner.capture())
                let _: Any? = try joiner.value()

                // Sync on the ids
                ctx.coll.sync.sync(ids: docIds, joiner.capture())
                let _: Any? = try joiner.value()

                // Perform the sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Shuffle the document ids
                docIds.shuffle()

                // Remotely update the desired percentage of documents
                var numDocsChanged = Int(Double(numDocs) * changeEventPercentage)
                try SyncPerformanceTestUtils.performRemoteUpdate(ctx: ctx, ids: Array(docIds.prefix(numDocsChanged)))
                numRemoteDocsChanged = numDocsChanged

                // Locally update the desired percentage of documents
                numDocsChanged = Int(Double(numDocs) * changeEventPercentage * conflictPercentage)
                try SyncPerformanceTestUtils.performLocalUpdate(ctx: ctx, ids: Array(docIds.prefix(numDocsChanged)))

        }, testDefinition: { ctx, _, _ in
            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            // Verify that the local and remote collections have the right number of documents
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

            // Verify that the updates were applied locally.
            // Both the local and remote should have remoteNum documents with {newField: "remote"}
            guard let remoteNum = numRemoteDocsChanged else {
                throw "Could not read numRemoteDocsChanged \(numRemoteDocsChanged ?? -1)"
            }

            let joiner = ThrowingCallbackJoiner()
            ctx.coll.count(["newField": "remote"], options: nil, joiner.capture())
            guard let remoteCount: Int = try joiner.value() else {
                throw "Remote Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(remoteCount, remoteNum,
                                                                message: "Number of remote documents updated")

            ctx.coll.sync.count(filter: ["newField": "remote"], options: nil, joiner.capture())
            guard let localCount: Int = try joiner.value() else {
                throw "Local Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(remoteCount, localCount,
                                                                message: "Number of local documents updated")
        }, extraFields: [
            "percentageChangeEvent": changeEventPercentage,
            "percentageConflict": conflictPercentage]
        )
    }
}
