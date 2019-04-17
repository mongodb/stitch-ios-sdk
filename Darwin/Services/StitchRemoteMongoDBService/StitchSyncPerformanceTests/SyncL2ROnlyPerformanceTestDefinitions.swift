// swiftlint:disable function_body_length

import XCTest
import Foundation
import MongoSwift
@testable import StitchRemoteMongoDBService
@testable import StitchCoreRemoteMongoDBService

class SyncL2ROnlyPerformanceTestDefinitions {
    private static let TAG = SyncL2ROnlyPerformanceTestDefinitions.self

    // NOTE: Many of the tests above 1024 bytes and above 500 docs will fail for various
    // reasons because they hit undocumented limits. These failures along with stacktraces will
    // be present in the reported results
    private let docSizes = [1024, 2048, 5120, 10240, 25600, 51200, 102400]
    private let numDocs = [100, 500, 1000, 5000, 10000, 25000]

    static func testInitialSync(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "testL2R_InitialSync"
        print(testName)

        // Local variable for list of documents captured by the test definition closures below.
        // This should change for each iteration of the test.
        var documentsForCurrentTest: [Document] = []

        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            testDefinition: { (ctx, numDocs, docSize) in
                // Initial sync for a purely L2R scenario means inserting local documents,
                // and performing a sync pass to sync those documents up to the remote.
                let sync = ctx.coll.sync

                // If sync fails for any reason, halt the test
                sync.configure(
                    conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                    changeEventDelegate: nil,
                    errorListener: { error, id in
                        print(
                        "unexpected sync error with id " +
                            "\(String(describing: id)): \(error)"
                        )
                        fatalError(error.localizedDescription)
                    }
                )

                ctx.coll.sync.insertMany(&documentsForCurrentTest)

                // Halt the test if the sync pass failed
                guard let passed = try? ctx.coll.sync.proxy.dataSynchronizer.doSyncPass(),
                    passed else {
                    XCTFail("sync pass failed")
                    return
                }
            }, beforeEach: { (ctx, numDocs, docSize) in
                // Generate the documents that are to be synced via L2R
                print("Setting up \(testName) for \(numDocs) \(docSize)-byte docs")
                documentsForCurrentTest = SyncPerformanceTestUtils.generateDocuments(numDoc: numDocs, docSize: docSize)
            }, afterEach: { (ctx, numDocs, _) in
                // Verify that the test did indeed synchronize
                // the provided documents remotely
                let numOfDocsSynced = ctx.coll.count(Document())
                if numDocs != numOfDocsSynced {
                    print(TAG, "$numDocs != $numOfDocsSynced")
                    XCTFail("test did not correctly perform the initial sync")
                }
            })
    }

    static func testDisconnectReconnect(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        let testName = "testL2R_DisconnectReconnect"
        print(TAG, testName)

        var documentsForCurrentTest: [Document] = []
        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            testDefinition: { (ctx, numDocs, docSize) in
                // Reconnect the DataSynchronizer, and wait for the streams to reopen. The
                // stream being open indicates that the doc configs are now set as stale.
                // Check every 10ms so we're not doing too much work on this thread, and
                // don't log anything, so as not to pollute the test results with logging
                // overhead.
                ctx.networkMonitor.state = .connected
                var counter = 0
                while !ctx.dataSynchronizer.allStreamsAreOpen {
                    sleep(1)

                    // if this hangs longer than 30 seconds, throw an error
                    counter += 1
                    if counter > 3000 {
                        print(TAG, "stream never opened after reconnect")
                        fatalError("stream never opened after reconnect")
                    }
                }

                // Do the sync pass that will perform the stale document fetch
                guard let syncPassSucceeded = try? ctx.dataSynchronizer.doSyncPass(),
                    syncPassSucceeded else {
                    fatalError("sync pass failed")
                }
        }, beforeEach: { (ctx, numDocs, docSize) in
            // Generate and insert the documents, and perform the initial sync.
            print(TAG, "Setting up $testName for $numDocs $docSize-byte docs")
            documentsForCurrentTest = SyncPerformanceTestUtils.generateDocuments(numDoc: numDocs, docSize: docSize)

            let sync = ctx.coll.sync

            // If sync fails for any reason, halt the test
            sync.configure(
                conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                changeEventDelegate: nil,
                errorListener: { error, id in
                    print(
                        "unexpected sync error with id " +
                        "\(String(describing: id)): \(error)"
                    )
                    fatalError(error.localizedDescription)
            }
            )

            ctx.coll.sync.insertMany(&documentsForCurrentTest)

            // Halt the test if the sync pass failed
            guard let passed = try? ctx.coll.sync.proxy.dataSynchronizer.doSyncPass(),
                passed else {
                    XCTFail("sync pass failed")
                    return
            }

            // Disconnect the DataSynchronizer and wait
            // for the underlying streams to close
            ctx.networkMonitor.state = .connected
            while ctx.dataSynchronizer.allStreamsAreOpen {
                print(TAG, "waiting for streams to close")
                sleep(1)
            }
        }, afterEach: { (ctx, numDocs, _) in
            // Verify that the test did indeed synchronize
            // the provided documents remotely
            let numOfDocsSynced = ctx.coll.count(Document())
            if numDocs != numOfDocsSynced {
                print(TAG, "$numDocs != $numOfDocsSynced")
                fatalError("test did not correctly perform the initial sync")
            }
        })
    }

    static func testSyncPass(testHarness: SyncPerformanceIntTestHarness, runId: ObjectId) {
        // Do an L2R sync pass test where
        // - no documents are changed
        // - 1% of documents are changed
        // - 10% of documents are changed
        // - 25% of documents are changed
        // - 50% of documents are changed
        // - 100% of documents are changed
        let changeEventPercentages = [0.0, 0.01, 0.10, 0.25, 0.50, 1.0]

        changeEventPercentages.forEach {
            doTestSyncPass(testHarness: testHarness, runId: runId, pctOfDocsWithChangeEvents: $0)
        }
    }

    private static func doTestSyncPass(
        testHarness: SyncPerformanceIntTestHarness,
        runId: ObjectId,
        pctOfDocsWithChangeEvents: Double
    ) {
        let testName = "testL2R_SyncPass_${pctOfDocsWithChangeEvents}DocsChanged"
        print(TAG, testName)

        // Local variable for the number of docs updated in the test
        // This should change for each iteration of the test.
        var numberOfChangedDocs: Int?

        testHarness.runPerformanceTestWithParameters(
            testName: testName,
            runId: runId,
            testDefinition: { (ctx, numDocs, docSize) in
                // Do the sync pass that will sync the
                // local changes to the remote collection
                guard let syncPassSucceeded = try? ctx.dataSynchronizer.doSyncPass(),
                    syncPassSucceeded else {
                    // Halt the test if the sync pass failed
                    fatalError("sync pass failed")
                }
        }, beforeEach: { (ctx, numDocs, docSize) in
            // Generate and insert the documents, and perform the initial sync.
            print(TAG, "Setting up $testName test for $numDocs $docSize-byte docs")
            var documentsForCurrentTest =
                SyncPerformanceTestUtils.generateDocuments(numDoc: numDocs, docSize: docSize)

            // Initial sync for a purely L2R scenario means inserting local documents,
            // and performing a sync pass to sync those documents up to the remote.
            let sync = ctx.coll.sync

            // If sync fails for any reason, halt the test
            sync.configure(
                conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                changeEventDelegate: nil,
                errorListener: { error, id in
                    print(
                        "unexpected sync error with id " +
                        "\(String(describing: id)): \(error)"
                    )
                    fatalError(error.localizedDescription)
            })
            sync.insertMany(&documentsForCurrentTest)

            guard let syncPassSucceeded = try? ctx.dataSynchronizer.doSyncPass(),
                syncPassSucceeded else {
                // Halt the test if the sync pass failed
                fatalError("sync pass failed")
            }

            // Randomly sample a percentage of the documents
            // that will be locally updated
            let shuffledDocs = documentsForCurrentTest.shuffled()

            let docsToUpdate = pctOfDocsWithChangeEvents > 0.0 ?
                shuffledDocs.prefix(upTo: Int(pctOfDocsWithChangeEvents * Double(numDocs))) :
                []

            docsToUpdate.forEach {
                _ = sync.updateOne(
                    filter: ["_id": $0["_id"] ?? BSONNull()],
                    update: ["$set": ["newField": "blah"] as Document]
                )
            }

            numberOfChangedDocs = docsToUpdate.count
        }, afterEach: { (ctx, numDocs, _) in
            // Verify that the test did indeed synchronize
            // the provided documents remotely
            let numOfDocsSynced = ctx.coll.count(Document())
            if numDocs != numOfDocsSynced {
                print(TAG, "\(numDocs) != \(String(describing: numOfDocsSynced))")
                fatalError("test did not correctly perform the initial sync")
            }

            // Verify that the test did indeed synchronize the provided documents
            // remotely, and that the documents that were supposed to be updated got
            // updated.
            let numOfDocsWithNewField = ctx.coll.count(["newField": ["$exists", true]])
            if numberOfChangedDocs != numOfDocsWithNewField {
                print(TAG, "$numberOfChangedDocs != $numOfDocsWithNewField")
                fatalError("test did not correctly perform the l2r pass")
            }
        })
    }
}
