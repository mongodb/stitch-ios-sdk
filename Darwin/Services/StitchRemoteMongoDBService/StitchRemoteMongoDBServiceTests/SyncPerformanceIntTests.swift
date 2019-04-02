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

class SyncPerformanceIntTests: BaseStitchIntTestCocoaTouch {
    let harness = SyncPerformanceIntTestHarness()
    static let runId = ObjectId()
    let joiner = ThrowingCallbackJoiner()

    func testFailure() {
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
        }, customSetup: {_, numDoc, docSize in
            print("PerfLog: (Custom Setup) \(numDoc) docs of size \(docSize)")
        }, customTeardown: {_, numDoc, docSize in
            print("PerfLog: (Custom Teardown) \(numDoc) docs of size \(docSize)")
        })
    }

    func testInitialSyncLocal() {
        let testParam = TestParams(testName: "initialSyncLocal",
                                   runId: SyncPerformanceIntTests.runId,
                                   numIters: 3,
                                   numDocs: [5, 10],
                                   docSizes: [10, 20])
        harness.runPerformanceTestWithParameters(testParams: testParam, testDefinition: {ctx, numDoc, docSize in
            print("PerfLog: Test: \(numDoc) docs of size \(docSize)")
            let docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.insertMany(docs, joiner.capture())
            let _: Any? = try joiner.value()
        }, customSetup: {_, numDoc, docSize in
            print("PerfLog: (Custom Setup) \(numDoc) docs of size \(docSize)")
        }, customTeardown: {_, numDoc, docSize in
            print("PerfLog: (Custom Teardown) \(numDoc) docs of size \(docSize)")
        })
    }

    func testInitialSyncProd() {
        let testParam = TestParams(testName: "initialSyncProd",
                                   runId: SyncPerformanceIntTests.runId,
                                   numIters: 3,
                                   numDocs: [5, 10],
                                   docSizes: [10, 20],
                                   stitchHostName: "https://stitch.mongodb.com")
        harness.runPerformanceTestWithParameters(testParams: testParam, testDefinition: {ctx, numDoc, docSize in
            print("PerfLog: Test: \(numDoc) docs of size \(docSize)")
            let docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.insertMany(docs, joiner.capture())
            let _: Any? = try joiner.value()
        })
    }

    func getDocuments(numDocs: Int, docSize: Int) -> [Document] {
        var docs: [Document] = []
        for iter in 1...numDocs {
            do {
                let newDoc: Document = try ["_id": ObjectId(),
                                            "data": Binary(data: Data(repeating: UInt8(iter % 100), count: docSize),
                                                           subtype: Binary.Subtype.userDefined)]
                docs.append(newDoc)
            } catch {
                print("PerfLog: Failed to make array of documents with err: \(error.localizedDescription)")
            }
        }
        return docs
    }
}
