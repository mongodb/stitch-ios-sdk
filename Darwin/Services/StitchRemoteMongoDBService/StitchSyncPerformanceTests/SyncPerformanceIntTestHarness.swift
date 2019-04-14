// swiftlint:disable force_try
import Foundation
import XCTest
import MongoSwift
@testable import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

typealias TestDefinition = (_ ctx: SyncPerformanceTestContext, _ numDoc: Int, _ docSize: Int) throws -> Void
typealias SetupDefinition = (_ ctx: SyncPerformanceTestContext, _ numDoc: Int, _ docSize: Int) throws -> Void
typealias TeardownDefinition = (_ ctx: SyncPerformanceTestContext, _ numDoc: Int, _ docSize: Int) throws -> Void

let testStitchAPIKey = TEST_PERF_IOS_API_KEY.isEmpty ?
    ProcessInfo.processInfo.environment["PERF_IOS_API_KEY"] : TEST_PERF_IOS_API_KEY

class SyncPerformanceIntTestHarness: BaseStitchIntTestCocoaTouch {

    // Private Constants
    private let mongodbUriProp = "test.stitch.mongodbURI"
    private let stitchAPIKeyProp = "test.stitch.iosPerfStitchAPIKey"
    private let stitchOutputAppName = "ios-sdk-perf-testing-alfgp"
    private let stitchOutputDbName = "performance"
    private let stitchOutputCollName = "results"
    private let callbackJoiner = ThrowingCallbackJoiner()

    // internal constants
    internal let stitchTestDbName = "performance"
    internal let stitchTestCollName = "rawTestCollSwift"
    internal let stitchProdHost = "https://stitch.mongodb.com"

    // Provate lazy vars
    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))
    private lazy var stitchAPIKey: String = pList?[stitchAPIKeyProp] as? String ?? ""
    private lazy var hostName = ProcessInfo.processInfo.environment["EVERGREEN_HOST"] ?? "Local"

    // Internal vars
    internal var networkTransport = FoundationInstrumentedHTTPTransport()
    internal lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"
    internal var outputClient: StitchAppClient!
    internal var outputMongoClient: RemoteMongoClient!
    internal var outputColl: RemoteMongoCollection<Document>!

    lazy var setupOutputClient: Bool = {
        if outputClient == nil {
            do {
                outputClient = try Stitch.appClient(forAppID: stitchOutputAppName)
            } catch {
                let config = StitchAppClientConfigurationBuilder()
                    .with(transport: networkTransport)
                    .with(networkMonitor: networkMonitor).build()
                outputClient = try! Stitch.initializeAppClient(withClientAppID: stitchOutputAppName, withConfig: config)
            }
        }

        if !(outputClient?.auth.isLoggedIn ?? false) {
            guard let testStitchAPIKey = testStitchAPIKey else {
                XCTFail("No PERF_IOS_API_KEY preprocessor macros; "
                    + "testStitchAPIKey is null")
                return false
            }

            guard !(testStitchAPIKey.isEmpty) else {
                XCTFail("No PERF_IOS_API_KEY preprocessor macros; "
                    + "failing test. See README for more details.")
                return false
            }

            outputClient?.auth.login(withCredential: UserAPIKeyCredential(withKey: testStitchAPIKey),
                                     callbackJoiner.capture())
        }

        outputMongoClient = try! outputClient?.serviceClient(fromFactory: remoteMongoClientFactory,
                                                             withName: "mongodb-atlas")
        outputColl = outputMongoClient?.db(stitchOutputDbName).collection(stitchOutputCollName)

        return true
    }()

    override func setUp() {
        super.setUp()
    }

    func createPerformanceTestingContext() throws -> SyncPerformanceTestContext {
        if SyncPerformanceTestUtils.stitchHostName == "https://stitch.mongodb.com" {
            return try ProductionPerformanceTestContext(harness: self)
        } else {
            return try LocalPerformanceTestContext(harness: self)
        }
    }

    private func handleTestResults(runResults: Document, resultId: ObjectId) -> Bool {
        let success = runResults.hasKey("timeMs")

        logMessage(message: "\(success ? "Success" : "Failure"): \(runResults.canonicalExtendedJSON)")

        if SyncPerformanceTestUtils.shouldOutputToStitch {
            _ = outputColl?.updateOne(filter: ["_id": resultId],
                                      update: ["$push": ["results": runResults] as Document])
        }

        return success
    }

    private func outputTestParams(testName: String, runId: ObjectId, resultId: ObjectId) {
        var testParams = TestParams(withTestName: testName, withRunId: runId)

        logMessage(message: "Starting Test: \(testParams.asBson)")

        if SyncPerformanceTestUtils.shouldOutputToStitch {
            var params = testParams.asBson
            params["_id"] = resultId
            params["status"] = "In Progress"
            params["hostName"] = hostName
            outputColl?.insertOne(params)
        }
    }

    internal func logMessage(message: String) {
        if SyncPerformanceTestUtils.shouldOutputToStdOut {
             print("PerfLog: \(message)")
        }
    }

    func runPerformanceTestWithParameters(testName: String,
                                          runId: ObjectId,
                                          testDefinition: TestDefinition,
                                          beforeEach: SetupDefinition = { _, _, _ in },
                                          afterEach: TeardownDefinition = { _, _, _ in }) {
        var failed = false
        let resultId = ObjectId()

        guard setupOutputClient == true else {
            return
        }

        outputTestParams(testName: testName, runId: runId, resultId: resultId)

        for docSize in SyncPerformanceTestUtils.docSizes {
            for numDoc in SyncPerformanceTestUtils.numDocs {

                let runResults = RunResults(numDocs: numDoc, docSize: docSize)
                for iter in 0..<SyncPerformanceTestUtils.numIters {
                    do {
                        let ctx = try createPerformanceTestingContext()

                        let iterResult = try ctx.runSingleIteration(numDocs: numDoc,
                                                                    docSize: docSize,
                                                                    testDefinition: testDefinition,
                                                                    setup: beforeEach,
                                                                    teardown: afterEach)

                        runResults.addResult(iterResult: iterResult)
                        try ctx.tearDown()
                    } catch {
                        let message = "Failed on iteration \(iter) of \(SyncPerformanceTestUtils.numIters)" +
                        "with error \(String(describing: error))"
                        runResults.addFailure(failureResult: FailureResult(
                            iteration: iter,
                            reason: message,
                            stackTrace: Thread.callStackSymbols))

                        if SyncPerformanceTestUtils.shouldOutputToStdOut {
                            logMessage(message: "Error \(message)")
                        }
                    }
                }

                if handleTestResults(runResults: runResults.asBson, resultId: resultId) == false {
                    failed = true
                }

            }
        }

        if SyncPerformanceTestUtils.shouldOutputToStitch {
            let resStr = failed ? "Failure" : "Success"
            _ = outputColl?.updateOne(filter: ["_id": resultId],
                                      update: ["$set": ["status": resStr] as Document])
        }
    }
}

internal struct TestParams {
    let testName: String
    let runId: ObjectId

    init(withTestName testName: String, withRunId runId: ObjectId) {
        self.testName = testName
        self.runId = runId
    }

    lazy var asBson: Document = [
        "testName": testName,
        "runId": runId,
        "numIters": SyncPerformanceTestUtils.numIters,
        "dataProbeGranularityMs": SyncPerformanceTestUtils.dataGranularity,
        "numOutliersEachSide": SyncPerformanceTestUtils.numOutliers,
        "stitchHostName": SyncPerformanceTestUtils.stitchHostName,
        "hostname": SyncPerformanceTestUtils.hostname,
        "date": Date(),
        "sdk": "ios",
        "results": []
    ]

}

class DataBlock {
    let mean: Double
    let median: Double
    let max: Double
    let min: Double
    let stdDev: Double

    init(data: [Double], numOutliers: Int) {
        if data.count >= numOutliers * 2 {
            let newData = Array(data.sorted()[numOutliers ... (data.count - numOutliers - 1)])
            max = newData.last ?? 0.0
            min = newData.first ?? 0.0

            let dataSize = newData.count
            let middle = dataSize / 2

            if dataSize % 2 == 0 {
                median = (newData[middle] + newData[middle - 1]) / 2
            } else {
                median = newData[middle]
            }

            mean = newData.reduce(0.0, +) / Double(newData.count)

            var sumOfSquared = 0.0
            for data in newData {
                sumOfSquared += (data - mean) * (data - mean)
            }
            stdDev = sqrt(sumOfSquared / Double(newData.count))
        } else {
            mean = 0.0
            median = 0.0
            max = 0.0
            min = 0.0
            stdDev = 0.0
        }
    }

    lazy var asBson: Document = [
        "mean": mean,
        "median": median,
        "max": max,
        "min": min,
        "stdDev": stdDev
    ]
}

internal class IterationResult {
    let executionTimeMs: Double
    let networkSentBytes: Double
    let networkReceivedBytes: Double
    let cpuUsagePercent: Double
    let memoryUsageBytes: Double
    let diskUsageBytes: Double
    let activeThreadCount: Double

    init(executionTimeMs: Double, networkSentBytes: Double, networkReceivedBytes: Double,
         cpuUsagePercent: Double, memoryUsageBytes: Double, diskUsageBytes: Double, activeThreadCount: Double) {
        self.executionTimeMs = executionTimeMs
        self.networkSentBytes = networkSentBytes
        self.networkReceivedBytes = networkReceivedBytes
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsageBytes = memoryUsageBytes
        self.diskUsageBytes = diskUsageBytes
        self.activeThreadCount = activeThreadCount
    }
}

private class FailureResult {
    private let iteration: Int
    private let reason: String
    private let stackTrace: [String]

    init(iteration: Int, reason: String, stackTrace: [String]) {
        self.iteration = iteration
        self.reason = reason
        self.stackTrace = stackTrace
    }

    lazy var asBson: Document = [
        "iteration": self.iteration,
        "reason": self.reason,
        "stackTrace": self.stackTrace
    ]
}

private class RunResults {
    let numDocs: Int
    let docSize: Int

    private var timeData: [Double] = []
    private var networkSentData: [Double] = []
    private var networkRecData: [Double] = []
    private var cpuUsageData: [Double] = []
    private var memoryUsageData: [Double] = []
    private var diskUsageData: [Double] = []
    private var activeThreadCountsData: [Double] = []
    private var failures: [FailureResult] = []

    init(numDocs: Int, docSize: Int) {
        self.numDocs = numDocs
        self.docSize = docSize
    }

    func addResult(iterResult: IterationResult) {
        self.timeData.append(iterResult.executionTimeMs)
        self.cpuUsageData.append(iterResult.cpuUsagePercent)
        self.memoryUsageData.append(iterResult.memoryUsageBytes)
        self.diskUsageData.append(iterResult.diskUsageBytes)
        self.activeThreadCountsData.append(iterResult.activeThreadCount)
        self.networkSentData.append(iterResult.networkSentBytes)
        self.networkRecData.append(iterResult.networkReceivedBytes)
    }

    func addFailure(failureResult: FailureResult) {
        self.failures.append(failureResult)
    }

    var asBson: Document {
        let failuresBson = self.failures.map { $0.asBson }
        if failures.count < (SyncPerformanceTestUtils.numIters + 1) / 2 {
            let numOutliers = SyncPerformanceTestUtils.numOutliers
            return [
                "numDocs": self.numDocs,
                "docSize": self.docSize,
                "success": true,
                "timeMs": DataBlock(data: self.timeData, numOutliers: numOutliers).asBson,
                "networkSentBytes": DataBlock(data: self.networkSentData, numOutliers: numOutliers).asBson,
                "networkReceivedBytes": DataBlock(data: self.networkRecData, numOutliers: numOutliers).asBson,
                "cpu": DataBlock(data: self.cpuUsageData, numOutliers: numOutliers).asBson,
                "memoryBytes": DataBlock(data: self.memoryUsageData, numOutliers: numOutliers).asBson,
                "diskBytes": DataBlock(data: self.diskUsageData, numOutliers: numOutliers).asBson,
                "diskEfficiencyRatio": DataBlock(data: self.diskUsageData.map({
                    $0 / Double((docSize + 12) * numDocs)
                }), numOutliers: numOutliers).asBson,
                "activeThreadCounts": DataBlock(data: self.activeThreadCountsData, numOutliers: numOutliers).asBson,
                "numFailures": failures.count,
                "failures": failuresBson
            ]
        } else {
            return [
                "numDocs": self.numDocs,
                "docSize": self.docSize,
                "success": false,
                "numFailures": failures.count,
                "failures": failuresBson
            ]
        }
    }
}
