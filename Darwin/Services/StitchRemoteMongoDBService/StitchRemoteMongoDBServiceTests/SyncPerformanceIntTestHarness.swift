// swiftlint:disable force_try
import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

typealias TestDefinition = (_ ctx: SyncPerformanceContext, _ numDoc: Int, _ docSize: Int) throws -> Void

class SyncPerformanceIntTestHarness: BaseStitchIntTestCocoaTouch {
    // Typealias for testDefinition

    // Private Constants
    private let mongodbUriProp = "test.stitch.mongodbURI"
    private let stitchAPIKeyProp = "test.stitch.iosPerfStitchAPIKey"
    private let stitchOutputAppName = "ios-sdk-perf-testing-alfgp"
    private let stitchOutputDbName = "performance"
    private let stitchOutputCollName = "results"
    private let networkTransport = FoundationInstrumentedHTTPTransport()
    private let callbackJoiner = ThrowingCallbackJoiner()

    // internal constants
    internal let stitchTestDbName = "performance"
    internal let stitchTestCollName = "rawTestColl"
    internal let stitchProdHost = "https://stitch.mongodb.com"

    // Provate lazy vars
    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))
    private lazy var stitchAPIKey: String = pList?[stitchAPIKeyProp] as? String ?? ""

    // Internal vars
    internal lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"
    internal var outputClient: StitchAppClient?
    internal var outputMongoClient: RemoteMongoClient?
    internal var outputColl: RemoteMongoCollection<Document>?

    override func setUp() {
        super.setUp()
        do {
            outputClient = try Stitch.appClient(forAppID: stitchOutputAppName)
        } catch {
            let config = StitchAppClientConfigurationBuilder()
                .with(transport: networkTransport)
                .with(networkMonitor: networkMonitor).build()
            outputClient = try! Stitch.initializeAppClient(withClientAppID: stitchOutputAppName, withConfig: config)
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

    override func tearDown() {
        super.tearDown()
    }

    func setUpIter() {

    }

    func tearDownIter() {

    }

    // swiftlint:disable function_body_length
    func runPerformanceTestWithParameters(testParams: TestParams,
                                          testDefinition: TestDefinition,
                                          customSetup: TestDefinition? = nil,
                                          customTeardown: TestDefinition? = nil) {
        setUp()

        let resultId = ObjectId()
        if testParams.outputToStitch {
            var params = testParams.toBson()
            params["_id"] = resultId
            params["status"] = "In Progress"
            outputColl?.insertOne(params)
        }

        var iteration = 0
        do {
            for docSize in testParams.docSizes {
                for numDoc in testParams.numDocs {
                    var timeData: [Double] = []
                    var cpuData: [Double] = []
                    var memoryData: [Double] = []
                    var diskData: [Double] = []
                    var threadData: [Double] = []
                    var networkSentData: [Double] = []
                    var networkReceivedData: [Double] = []

                    for iter in 1...testParams.numIters {
                        iteration = iter
                        let ctx = try SyncPerformanceContext(harness: self,
                                                         testParams: testParams,
                                                         transport: networkTransport)
                        let iterResult = try ctx.runSingleIteration(numDocs: numDoc, docSize: docSize,
                                                                    testDefinition: testDefinition,
                                                                    customSetup: customSetup,
                                                                    customTeardown: customTeardown)
                        timeData.append(iterResult.time)
                        cpuData.append(iterResult.cpu)
                        memoryData.append(iterResult.memory)
                        diskData.append(iterResult.disk)
                        threadData.append(iterResult.threads)
                        networkSentData.append(iterResult.networkSentBytes)
                        networkReceivedData.append(iterResult.networkReceivedBytes)

                        try ctx.tearDown()
                    }

                    let result = RunResults(numDocs: numDoc, docSize: docSize,
                                            numOutliers: testParams.numOutliersEachSide,
                                            time: timeData, networkSentBytes: networkSentData,
                                            networkReceivedBytes: networkReceivedData, cpu: cpuData,
                                            memory: memoryData, disk: diskData, threads: threadData)

                    if testParams.outputToStdOut {
                        print("PerfLog: \(result.toBson().canonicalExtendedJSON)")
                    }

                    if testParams.outputToStitch {
                        _ = outputColl?.updateOne(filter: ["_id": resultId],
                                                  update: ["$push": ["results": result.toBson()] as Document])
                    }
                }
            }

            if testParams.outputToStitch {
                _ = outputColl?.updateOne(filter: ["_id": resultId],
                                          update: ["$set": ["status": "Success"] as Document])
            }
        } catch {
            let failureMessage = """
            Failed on iteration \(iteration) of \(testParams.numIters)
            with error \(String(describing: error))
            """

            print("PerfLog: Harness Error: \(failureMessage)")
            if testParams.outputToStitch {
                _ = outputColl?.updateOne(filter: ["_id": resultId],
                                          update: ["$set": ["status": "Failed",
                                                            "failureReason": failureMessage] as Document])
            XCTFail(failureMessage)
            }
        }
    }
    // swiftlint:enable function_body_length
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
        numOutliersEachSide: Int = 1,
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

    func toBson() -> Document {
        return [
            "testName": testName,
            "runId": runId,
            "numIters": numIters,
            "dataProbeGranularityMs": dataProbeGranularityMs,
            "numOutliersEachSide": numOutliersEachSide,
            "stitchHostName": stitchHostName, // Todo: fix this
            "date": Date(),
            "sdk": "ios",
            "results": []
        ]
    }
}

struct DoubleDataBlock {
    var mean: Double = 0.0
    var median: Double = 0.0
    var max: Double = 0.0
    var min: Double = 0.0
    var stdDev: Double = 0.0

    init(data: [Double], numOutliers: Int) {
        if data.count >= numOutliers * 2 {
            let newData = Array(data.sorted()[numOutliers ... (data.count - numOutliers - 1)])
            max = newData.first ?? 0.0
            min = newData.last ?? 0.0

            let dataSize = newData.count
            let middle = dataSize / 2

            if dataSize % 2 == 0 {
                median = (newData[middle] + newData[middle - 1]) / 2
            } else {
                median = newData[middle]
            }

            mean = newData.reduce(0.0, +) / Double(newData.count)
            let sumOfSquared = newData.map {($0 - mean) * ($0 - mean)}.reduce(0, +)
            stdDev = sqrt(sumOfSquared / Double(newData.count))
        }
    }

    func toBson() -> Document {
        return [
            "mean": mean,
            "median": median,
            "max": max,
            "min": min,
            "stdDev": stdDev
        ]
    }
}

internal struct IterationResult {
    let time: Double
    let networkSentBytes: Double
    let networkReceivedBytes: Double
    let cpu: Double
    let memory: Double
    let disk: Double
    let threads: Double

    init(time: Double,
         networkSentBytes: Double,
         networkReceivedBytes: Double,
         cpu: Double,
         memory: Double,
         disk: Double,
         threads: Double) {
        self.time = time
        self.networkSentBytes = networkSentBytes
        self.networkReceivedBytes = networkReceivedBytes
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.threads = threads
    }

}

private struct RunResults {
    let numDocs: Int
    let docSize: Int
    let numOutliers: Int
    let time: DoubleDataBlock
    let networkSentBytes: DoubleDataBlock
    let networkReceivedBytes: DoubleDataBlock
    let cpu: DoubleDataBlock
    let memory: DoubleDataBlock
    let disk: DoubleDataBlock
    let diskEfficiencyRatio: DoubleDataBlock
    let threads: DoubleDataBlock

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
        self.time = DoubleDataBlock(data: time, numOutliers: numOutliers)
        self.networkSentBytes =
            DoubleDataBlock(data: networkSentBytes, numOutliers: numOutliers)
        self.networkReceivedBytes =
            DoubleDataBlock(data: networkReceivedBytes, numOutliers: numOutliers)
        self.cpu = DoubleDataBlock(data: cpu, numOutliers: numOutliers)
        self.memory = DoubleDataBlock(data: memory, numOutliers: numOutliers)
        self.disk = DoubleDataBlock(data: disk, numOutliers: numOutliers)
        self.threads = DoubleDataBlock(data: threads, numOutliers: numOutliers)

        let diskEfficiencyArr = disk.map({$0 / Double((docSize + 12) * numDocs)})
        self.diskEfficiencyRatio = DoubleDataBlock(data: diskEfficiencyArr, numOutliers: numOutliers)

    }

    func toBson() -> Document {
        return [
            "numDocs": numDocs,
            "docSize": docSize,
            "timeMs": time.toBson(),
            "networkSentBytes": networkSentBytes.toBson(),
            "networkReceivedBytes": networkReceivedBytes.toBson(),
            "cpu": cpu.toBson(),
            "memoryBytes": memory.toBson(),
            "diskBytes": disk.toBson(),
            "diskEfficiencyRatio": diskEfficiencyRatio.toBson(),
            "threads": threads.toBson()
        ]
    }
}
