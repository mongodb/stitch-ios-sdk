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

// This is how we want to do things once we create the new test scheme and import the .h file as an
// objective-c bridging header
// let testStitchAPIKey = PERF_IOS_API_KEY.isEmpty ?
//    ProcessInfo.processInfo.environment["PERF_IOS_API_KEY"] : PERF_IOS_API_KEY

class SyncPerformanceIntTestHarness: BaseStitchIntTestCocoaTouch {
    // Typealias for testDefinition

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

    func setupOutputClient() {
        Stitch.clearApps()
        if outputClient == nil {
            do {
                outputClient = try Stitch.appClient(forAppID: stitchOutputAppName)
                print("PerfLog: *** Got cached appClient")
            } catch {
                print("PerfLog: *** Initializing new app client")
                let config = StitchAppClientConfigurationBuilder()
                    .with(transport: networkTransport)
                    .with(networkMonitor: networkMonitor).build()
                outputClient = try! Stitch.initializeAppClient(withClientAppID: stitchOutputAppName, withConfig: config)
            }
        } else {
            print("PerfLog: *** Skipping getting the output client")
        }

        if !(outputClient?.auth.isLoggedIn ?? false) {
            let apiKeyOpt = ProcessInfo.processInfo.environment["PERF_IOS_API_KEY"]
            guard let apiKey = apiKeyOpt else {
                XCTFail("No proper iOS-API-Key for stitch perf project gixen")
                return
            }

            outputClient?.auth.login(withCredential: UserAPIKeyCredential(withKey: apiKey), callbackJoiner.capture())
        }

        outputMongoClient = try! outputClient?.serviceClient(fromFactory: remoteMongoClientFactory,
                                                             withName: "mongodb-atlas")
        outputColl = outputMongoClient?.db(stitchOutputDbName).collection(stitchOutputCollName)
    }

    override func setUp() {
        super.setUp()
    }

    // swiftlint:disable function_body_length
    func runPerformanceTestWithParameters(testParams: TestParams,
                                          testDefinition: TestDefinition,
                                          beforeEach: SetupDefinition = { _, _, _ in },
                                          afterEach: TeardownDefinition = { _, _, _ in }) {
        var failed = false
        networkTransport = FoundationInstrumentedHTTPTransport()
        print("PerfLog: after creation \(networkTransport.bytesUploaded) : \(networkTransport.bytesDownloaded)")
        setupOutputClient()

        let resultId = ObjectId()
        if testParams.outputToStitch {
            var paramsNew = testParams
            var params = paramsNew.asBson
            params["_id"] = resultId
            params["status"] = "In Progress"
            params["hostName"] = hostName
            outputColl?.insertOne(params)
        }

         print("PerfLog: after stitch insert \(networkTransport.bytesUploaded) : \(networkTransport.bytesDownloaded)")
        for docSize in testParams.docSizes {
            nextTest: for numDoc in testParams.numDocs {
                var timeData: [Double] = []
                var cpuData: [Double] = []
                var memoryData: [Double] = []
                var diskData: [Double] = []
                var threadData: [Double] = []
                var networkSentData: [Double] = []
                var networkReceivedData: [Double] = []

                for iter in 1...testParams.numIters {
                    do {
                        var ctx: SyncPerformanceTestContext
                         print("PerfLog: before create context \(networkTransport.bytesUploaded) : \(networkTransport.bytesDownloaded)")
                        if testParams.stitchHostName == "https://stitch.mongodb.com" {
                            ctx = try ProductionPerformanceTestContext(harness: self, testParams: testParams)
                        } else {
                            ctx = try LocalPerformanceTestContext(harness: self, testParams: testParams)
                        }
                        
                        print("PerfLog: before run \(networkTransport.bytesUploaded) : \(networkTransport.bytesDownloaded)")
                        let iterResult = try ctx.runSingleIteration(numDocs: numDoc,
                                                                    docSize: docSize,
                                                                    testDefinition: testDefinition,
                                                                    setup: beforeEach,
                                                                    teardown: afterEach)
                         print("PerfLog: after run \(networkTransport.bytesUploaded) : \(networkTransport.bytesDownloaded)")
                        timeData.append(iterResult.executionTimeMs)
                        cpuData.append(iterResult.cpuUsagePercent)
                        memoryData.append(iterResult.memoryUsageBytes)
                        diskData.append(iterResult.diskUsageBytes)
                        threadData.append(iterResult.activeThreadCount)
                        networkSentData.append(iterResult.networkSentBytes)
                        networkReceivedData.append(iterResult.networkReceivedBytes)

                        try ctx.tearDown()
                    } catch {
                        failed = true
                        handleFailure(error: error, resultId: resultId, numDoc: numDoc, docSize: docSize,
                                      iter: iter, numIters: testParams.numIters,
                                      outputToStitch: testParams.outputToStitch)
                        continue nextTest
                    }
                }

                let result = RunResults(numDocs: numDoc, docSize: docSize,
                                        numOutliers: testParams.numOutliersEachSide,
                                        time: timeData, networkSentBytes: networkSentData,
                                        networkReceivedBytes: networkReceivedData, cpu: cpuData,
                                        memory: memoryData, disk: diskData, threads: threadData)

                if testParams.outputToStdOut {
                    print("PerfLog: \(result.asBson.canonicalExtendedJSON)")
                }

                if testParams.outputToStitch {
                    _ = outputColl?.updateOne(filter: ["_id": resultId],
                                              update: ["$push": ["results": result.asBson] as Document])
                }
            }
        }

        if testParams.outputToStitch {
            let resStr = failed ? "Failure" : "Success"
            _ = outputColl?.updateOne(filter: ["_id": resultId],
                                      update: ["$set": ["status": resStr] as Document])
        }

        if failed {
            XCTFail("Failed Test \(testParams.testName)")
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:disable function_parameter_count
    func handleFailure(error: Error, resultId: ObjectId, numDoc: Int, docSize: Int,
                       iter: Int, numIters: Int, outputToStitch: Bool) {
        let failureMessage = "Failed on iteration \(iter) of \(numIters) with error \(String(describing: error))"

        print("PerfLog: Harness Error: \(failureMessage)")
        if outputToStitch {
            let failureDoc: Document = [
                "numDocs": numDoc,
                "docSize": docSize,
                "status": "failure",
                "failureReason": failureMessage,
                "failureCallStack": Thread.callStackSymbols
            ]
            _ = outputColl?.updateOne(filter: ["_id": resultId],
                                      update: ["$push": ["results": failureDoc] as Document])
        }
    }
    // swiftlint:enable function_parameter_count
}

internal struct TestParams {
    let testName: String
    let runId: ObjectId
    let numIters: Int
    let numDocs: [Int]
    let docSizes: [Int]
    let dataProbeGranularityMs: Int
    let numOutliersEachSide: Int
    let stitchHostName: String
    let outputToStdOut: Bool
    let outputToStitch: Bool
    let preserveRawOutput: Bool

    init(
        testName: String,
        runId: ObjectId,
        numIters: Int = 12,
        numDocs: [Int] = [],
        docSizes: [Int] = [],
        dataProbeGranularityMs: Int = 1500,
        numOutliersEachSide: Int = 0,
        stitchHostName: String = "",
        outputToStdOut: Bool = true,
        outputToStitch: Bool = true,
        preserveRawOutput: Bool = false
    ) {
        self.testName = testName
        self.runId = runId
        self.numIters = numIters
        self.numDocs = numDocs
        self.docSizes = docSizes
        self.dataProbeGranularityMs = dataProbeGranularityMs
        self.numOutliersEachSide = numOutliersEachSide
        self.stitchHostName = stitchHostName
        self.outputToStdOut = outputToStdOut
        self.outputToStitch = outputToStitch
        self.preserveRawOutput = preserveRawOutput
    }

    lazy var asBson: Document = [
        "testName": testName,
        "runId": runId,
        "numIters": numIters,
        "dataProbeGranularityMs": dataProbeGranularityMs,
        "numOutliersEachSide": numOutliersEachSide,
        "stitchHostName": stitchHostName,
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

private class RunResults {
    let numDocs: Int
    let docSize: Int
    let numOutliers: Int
    let executionTimeMsData: DataBlock
    let networkSentBytesData: DataBlock
    let networkReceivedBytesData: DataBlock
    let cpuUsagePercentageData: DataBlock
    let memoryUsageBytesData: DataBlock
    let diskUsageBytesData: DataBlock
    let diskEfficiencyRatioData: DataBlock
    let activeThreadCountsData: DataBlock

    init(numDocs: Int,
         docSize: Int,
         numOutliers: Int,
         time: [Double],
         networkSentBytes: [Double],
         networkReceivedBytes: [Double],
         cpu: [Double],
         memory: [Double],
         disk: [Double],
         threads: [Double]) {
        self.numDocs = numDocs
        self.docSize = docSize
        self.numOutliers = numOutliers
        self.executionTimeMsData = DataBlock(data: time, numOutliers: numOutliers)
        self.networkSentBytesData = DataBlock(data: networkSentBytes, numOutliers: numOutliers)
        self.networkReceivedBytesData = DataBlock(data: networkReceivedBytes, numOutliers: numOutliers)
        self.cpuUsagePercentageData = DataBlock(data: cpu, numOutliers: numOutliers)
        self.memoryUsageBytesData = DataBlock(data: memory, numOutliers: numOutliers)
        self.diskUsageBytesData = DataBlock(data: disk, numOutliers: numOutliers)
        self.activeThreadCountsData = DataBlock(data: threads, numOutliers: numOutliers)

        let diskEfficiencyArr = disk.map({$0 / Double((docSize + 12) * numDocs)})
        self.diskEfficiencyRatioData = DataBlock(data: diskEfficiencyArr, numOutliers: numOutliers)

    }

    lazy var asBson: Document = [
        "numDocs": self.numDocs,
        "docSize": self.docSize,
        "status": "success",
        "timeMs": self.executionTimeMsData.asBson,
        "networkSentBytes": self.networkSentBytesData.asBson,
        "networkReceivedBytes": self.networkReceivedBytesData.asBson,
        "cpu": self.cpuUsagePercentageData.asBson,
        "memoryBytes": self.memoryUsageBytesData.asBson,
        "diskBytes": self.diskUsageBytesData.asBson,
        "diskEfficiencyRatio": self.diskEfficiencyRatioData.asBson,
        "activeThreadCounts": self.activeThreadCountsData.asBson
    ]
}
