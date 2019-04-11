import XCTest
@testable import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

import Foundation

class XCMongoMobileConfiguration: NSObject, XCTestObservation {
    // This init is called first thing as the test bundle starts up and before any test
    // initialization happens
    override init() {
        super.init()
        // We don't need to do any real work, other than register for callbacks
        // when the test suite progresses.
        // XCTestObservation keeps a strong reference to observers
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        try? CoreLocalMongoDBService.shared.initialize()
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        CoreLocalMongoDBService.shared.close()
    }
}

let harness = SyncPerformanceIntTestHarness()
let runId = ObjectId()

class SyncPerformanceIntTests: XCTestCase {
    let joiner = ThrowingCallbackJoiner()

    // This test should currently fail, it is just here to show proper test failure
    /* func testFailure() {
        let testParam = TestParams(testName: "shouldFail",
                                   runId: SyncPerformanceIntTests.runId,
                                   numIters: 3,
                                   numDocs: [5, 5000, 2],
                                   docSizes: [1, 10000, 3])
        harness.runPerformanceTestWithParameters(testParams: testParam, testDefinition: {ctx, numDoc, docSize in
            print("PerfLog: Test: \(numDoc) docs of size \(docSize)")
            let docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.insertMany(docs, joiner.capture())
            let _: Any? = try joiner.value()
        }, beforeEach: {_, numDoc, docSize in
            print("PerfLog: (Custom Setup) \(numDoc) docs of size \(docSize)")
        }, afterEach: {_, numDoc, docSize in
            print("PerfLog: (Custom Teardown) \(numDoc) docs of size \(docSize)")
        })
    } */

    func testInitialSyncLocal() {
        harness.runPerformanceTestWithParameters(
            testName: "intialSyncLocal",
            runId: runId,
            testDefinition: {ctx, numDoc, docSize in
                print("PerfLog: Test: \(numDoc) docs of size \(docSize)")

                if numDoc > 0 {
                    let docs = SyncPerformanceTestUtils.generateDocuments(numDoc: numDoc, docSize: docSize)
                    ctx.coll.insertMany(docs, joiner.capture())
                    let _: Any? = try joiner.value()
                    try assertEqual(Int.self, ctx.coll.count([:]) ?? 0, numDoc)
                }

                let count = ctx.coll.count([:])
                try assertEqual(Int.self, count ?? 0, numDoc)

                ctx.coll.sync.configure(conflictHandler: DefaultConflictHandler<Document>.remoteWins())

                if numDoc > 0 {
                    var docs = SyncPerformanceTestUtils.generateDocuments(numDoc: numDoc, docSize: docSize)
                    ctx.coll.sync.insertMany(&docs)
                    _ = try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass()
                    try assertEqual(Int.self, ctx.coll.sync.syncedIds().count, numDoc)
                }
            }, beforeEach: {_, numDoc, docSize in
                print("PerfLog: (Custom Setup) \(numDoc) docs of size \(docSize)")
            }, afterEach: {_, numDoc, docSize in
                print("PerfLog: (Custom Teardown) \(numDoc) docs of size \(docSize)")
            }
        )
    }

    // Custom assertEqual that throws so that the test fails if the assertion fails
    func assertEqual<T: Equatable>(_ type: T.Type, _ val1: Any, _ val2: Any) throws {
        guard let val1 = val1 as? T, let val2 = val2 as? T else {
            throw "assertEqual not passed valid params"
        }
        if val1 == val2 { return } else {
            throw "(\"\(val1)\") is not equal to (\"\(val2)\")"
        }
    }
}
