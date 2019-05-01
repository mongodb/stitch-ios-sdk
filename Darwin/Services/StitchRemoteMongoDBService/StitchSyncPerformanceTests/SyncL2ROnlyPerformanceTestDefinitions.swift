import XCTest
import Foundation
import MongoSwift
@testable import StitchRemoteMongoDBService
@testable import StitchCoreRemoteMongoDBService

class SyncL2ROnlyPerformanceTestDefinitions {

    /*
     * Before: Generate numDoc documents
     * Test: Perform local insert of numDoc documents and perform a sync pass
     * After: Ensure that the initial sync worked as expected
     */
    static func testInitialSync(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "L2R_InitialSync"
        var documentsForTest: [Document]?
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Generate the documents to insert locally
                documentsForTest = SyncPerformanceTestUtils.generateDocuments(numDoc: numDocs, docSize: docSize)
        }, testDefinition: { ctx, numDocs, docSize in
            guard let documents = documentsForTest else {
                throw "Setup function did not return generated documents"
            }

            // Configure the data synchronizer
            try SyncPerformanceTestUtils.configureSync(ctx: ctx)

            let joiner = ThrowingCallbackJoiner()
            ctx.coll.sync.insertMany(documents: documents, joiner.capture())
            guard let result: SyncInsertManyResult = try joiner.value() else {
                throw "Failed to insert \(numDocs) documents of size \(docSize) to remote"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(
                result.insertedIds.count,
                numDocs,
                message: "LocalInsert.insertedIds.count")

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            // Ensure the sync pass behaved properly
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)
        })
    }

    /*
     * Before: Perform local insert of numDoc documents, configure sync(),
     *              perform sync pass, disconnect networkMonitor
     * Test: Reconnect the network monitor and perform sync pass
     * After: Ensure that the sync pass worked as expected
     */
    static func testDisconnectReconnect(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "L2R_DisconnectReconnect"

        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Configure the data synchronizer
                try SyncPerformanceTestUtils.configureSync(ctx: ctx)

                // Insert the documents into the local collection
                try SyncPerformanceTestUtils.insertToLocal(ctx: ctx, numDocs: numDocs, docSize: docSize)

                // Perform the sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Disconnect the network monitor and wait until all streams are closed (max 30 seconds)
                try SyncPerformanceTestUtils.disconnectNetworkAndWaitForStreams(ctx: ctx)
        }, testDefinition: { ctx, _, _ in
            // Reconnect the network monitor and wait for streams to open (max 30 seconds)
            try SyncPerformanceTestUtils.connectNetworkAndWaitForStreams(ctx: ctx)

            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)
        }, afterEach: { ctx, numDocs, _ in
            // Verify that the test did indeed synchronize the updates locally
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)
        })
    }

    /*
     * Before: Perform local insert of numDoc documents, configure sync(), perform sync pass
     *              perform local update for numChangeEvent documents
     * Test: Perform sync pass
     * After: Ensure that the sync pass worked properly
     */
    static func testSyncPass(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        for changeEventPercentage in SyncPerformanceTestUtils.changeEventPercentages {
            doSyncPass(testHarness: testHarness, runId: runId, changeEventPercentage: changeEventPercentage)
        }
    }

    private static func doSyncPass(testHarness: SyncPerformanceIntTestHarness,
                                   runId: ObjectId,
                                   changeEventPercentage: Double) {
        let testName = "L2R_SyncPass"

        var numRemoteDocsChanged: Int?
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            beforeEach: { ctx, numDocs, docSize in
                // Configure the data synchronizer
                try SyncPerformanceTestUtils.configureSync(ctx: ctx)

                // Insert the documents locally
                var docIds = try SyncPerformanceTestUtils.insertToLocal(ctx: ctx, numDocs: numDocs, docSize: docSize)

                // Perform the sync pass
                try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

                // Verify that the sync pass worked properly
                try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

                // Shuffle the document ids
                docIds.shuffle()

                // Locally update the desired percentage of documents
                var numDocsChanged = Int(Double(numDocs) * changeEventPercentage)
                try SyncPerformanceTestUtils.performLocalUpdate(ctx: ctx, ids: Array(docIds.prefix(numDocsChanged)))
                numRemoteDocsChanged = numDocsChanged
        }, testDefinition: { ctx, _, _ in
            // Perform a sync pass
            try SyncPerformanceTestUtils.doSyncPass(ctx: ctx)

        }, afterEach: { ctx, numDocs, _ in
            // Verify that the local and remote collections have the right number of documents
            try SyncPerformanceTestUtils.assertLocalAndRemoteDBCount(ctx: ctx, numDocs: numDocs)

            // Verify that the updates were applied remotely.
            // Both the local and remote should have remoteNum documents with {newField: "remote"}
            guard let remoteNum = numRemoteDocsChanged else {
                throw "Could not read numRemoteDocsChanged \(numRemoteDocsChanged ?? -1)"
            }

            let joiner = ThrowingCallbackJoiner()
            ctx.coll.count(["newField": "local"], options: nil, joiner.capture())
            guard let remoteCount: Int = try joiner.value() else {
                throw "Remote Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(remoteCount, remoteNum,
                                                                message: "Number of remote documents updated")

            ctx.coll.sync.count(filter: ["newField": "local"], options: nil, joiner.capture())
            guard let localCount: Int = try joiner.value() else {
                throw "Local Count failed"
            }
            try SyncPerformanceTestUtils.assertIntsEqualOrThrow(remoteCount, localCount,
                                                                message: "Number of local documents updated")
        }, extraFields: [
            "percentageChangeEvent": changeEventPercentage
            ]
        )
    }
}
