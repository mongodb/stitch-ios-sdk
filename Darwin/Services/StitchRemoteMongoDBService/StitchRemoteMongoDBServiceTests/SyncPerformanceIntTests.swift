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

class SyncPerformanceIntTests: XCTestCase {
    let harness = SyncPerformanceIntTestHarness()
    static let runId = ObjectId()
    let joiner = ThrowingCallbackJoiner()

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
        let testParam = TestParams(testName: "initialSyncLocal",
                                   runId: SyncPerformanceIntTests.runId,
                                   numIters: 3,
                                   numDocs: [5, 10],
                                   docSizes: [10, 20])
        harness.runPerformanceTestWithParameters(testParams: testParam, testDefinition: {ctx, numDoc, docSize in
            print("PerfLog: Test: \(numDoc) docs of size \(docSize)")
            var docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.insertMany(docs, joiner.capture())
            let _: Any? = try joiner.value()

            let count = ctx.coll.count([:])
            try assertEqual(Int.self, count ?? 0, numDoc)

            ctx.coll.sync.configure(conflictHandler: DefaultConflictHandler<Document>.remoteWins())

            docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.sync.insertMany(&docs)
            _ = try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass()
            try assertEqual(Int.self, ctx.coll.sync.syncedIds().count, numDoc)

            docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.sync.insertMany(&docs)
            _ = try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass()
            try assertEqual(Int.self, ctx.coll.sync.syncedIds().count, 2 * numDoc)

        }, beforeEach: {_, numDoc, docSize in
            print("PerfLog: (Custom Setup) \(numDoc) docs of size \(docSize)")
        }, afterEach: {_, numDoc, docSize in
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
            try assertEqual(Int.self, ctx.coll.count([:]) ?? 1, 0)

            var docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.insertMany(docs, joiner.capture())
            let _: Any? = try joiner.value()

            ctx.coll.sync.configure(conflictHandler: DefaultConflictHandler<Document>.remoteWins())

            docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.sync.insertMany(&docs)
            _ = try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass()
            try assertEqual(Int.self, ctx.coll.sync.syncedIds().count, numDoc)

            docs = getDocuments(numDocs: numDoc, docSize: docSize)
            ctx.coll.sync.insertMany(&docs)
            _ = try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass()
            try assertEqual(Int.self, ctx.coll.sync.syncedIds().count, 2 * numDoc)

            try assertEqual(Int.self, ctx.coll.count([:]) ?? 0, 3 * numDoc)
        })
    }

    func getDocuments(numDocs: Int, docSize: Int) -> [Document] {
        return (0..<numDocs).map {iter in
            guard let newDoc = try? ["_id": ObjectId(),
                                     "data": Binary(data: Data(repeating: UInt8(iter % 100), count: docSize),
                                                    subtype: Binary.Subtype.userDefined)] as Document else {
                fatalError("Failed to create \(numDocs) documents of size \(docSize)")
            }
            return newDoc
        }
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
