//
//  SyncPerformanceTestHarness.swift
//  StitchRemoteMongoDBServiceTests
//
//  Created by Tyler Kaye on 3/28/19.
//  Copyright © 2019 MongoDB. All rights reserved.
//

import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

class SyncPerformanceIntTestHarness: BaseStitchIntTestCocoaTouch {
    typealias TestDefinition = (_ numDoc: Int, _ docSize: Int) -> Void
    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = ObjectId().oid
    private let collName = ObjectId().oid

    private var stitchClient: StitchAppClient!
    private var mongoClient: RemoteMongoClient!
    private lazy var ctx = SyncTestContext.init(stitchClient: self.stitchClient,
                                                mongoClient: self.mongoClient,
                                                networkMonitor: self.networkMonitor,
                                                dbName: self.dbName,
                                                collName: self.collName)

    private var userId1: String!

    override func setUp() {
        super.setUp()

//        try! prepareService()
//        let joiner = CallbackJoiner()
//        ctx.remoteCollAndSync.0.deleteMany([:], joiner.capture())
//        XCTAssertNotNil(joiner.capturedValue)
//        ctx.remoteCollAndSync.1.deleteMany(filter: [:], joiner.capture())
//        XCTAssertNotNil(joiner.capturedValue)
    }

    override func tearDown() {
//        ctx.teardown()
//        CoreLocalMongoDBService.shared.localInstances.forEach { client in
//            try! client.listDatabases().forEach {
//                try? client.db($0["name"] as! String).drop()
//            }
//        }
    }

    func setUpIter() {

    }

    func tearDownIter() {

    }

    func runPerformanceTestWithParameters(testParams: TestParams, testDefinition: TestDefinition) {
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

                    for _ in 1...testParams.numIters {
                        // Get starting values for disk space and time
                        let timeBefore = Date().timeIntervalSince1970
                        var systemAttributes =
                            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                        let freeSpaceBefore =
                            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0

                        // Start repeating task
                        // TODO: Eventually move this out into a separate method / var
                        let metricCollector = MetricsCollector(timeInterval: 0.5)
                        metricCollector.resume()

                        // Run function
                        testDefinition(numDoc, docSize)

                        // Stop timing and add it to timeData
                        timeData.append(Double(Date().timeIntervalSince1970 - timeBefore))

                        // Get the point-in-time measurements
                        let (threads, cpu, memory) = metricCollector.suspend()
                        threadData.append(threads)
                        cpuData.append(cpu)
                        memoryData.append(memory)

                        // Append remaining values
                        timeData.append(Double(Date().timeIntervalSince1970 - timeBefore))
                        networkSentData.append(10.0)
                        networkReceivedData.append(10.90)
                        systemAttributes =
                            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                        let freeSpaceAfter =
                            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
                        diskData.append(freeSpaceBefore - freeSpaceAfter)

                    }
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    func testInitialSync() {
        let testParam = TestParams(testName: "initialSync",
                                   runId: ObjectId(),
                                   numIters: 3,
                                   numDocs: [5],
                                   docSizes: [100])
        runPerformanceTestWithParameters(testParams: testParam) { numDoc, docSize in
            print("Test: \(numDoc) docs of size \(docSize)")
            sleep(3)
        }

    }

    func testDataBlock() {
        let dataBlock = DoubleDataBlock(data: [1.0, 1.1, 2.3, 2.4, 2.6, 2.9, 0.5], numOutliers: 1)
    }
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

private func cpuUsage() -> (Int, Double) {
    var kr: kern_return_t
    var taskInfoCount: mach_msg_type_number_t

    taskInfoCount = mach_msg_type_number_t(TASK_INFO_MAX)
    var tinfo = [integer_t](repeating: 0, count: Int(taskInfoCount))

    kr = task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), &tinfo, &taskInfoCount)
    if kr != KERN_SUCCESS {
        return (-1, -1.0)
    }

    var threadList: thread_act_array_t? = UnsafeMutablePointer(mutating: [thread_act_t]())
    var threadCount: mach_msg_type_number_t = 0
    defer {
        if let threadList = threadList {
            vm_deallocate(mach_task_self_, vm_address_t(UnsafePointer(threadList).pointee), vm_size_t(threadCount))
        }
    }

    kr = task_threads(mach_task_self_, &threadList, &threadCount)

    if kr != KERN_SUCCESS {
        return (-1, -1.0)
    }

    var totCPU: Double = 0

    if let threadList = threadList {

        for iter in 0 ..< Int(threadCount) {
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            var thinfo = [integer_t](repeating: 0, count: Int(threadInfoCount))
            kr = thread_info(threadList[iter], thread_flavor_t(THREAD_BASIC_INFO),
                             &thinfo, &threadInfoCount)
            if kr != KERN_SUCCESS {
                return (-1, -1.0)
            }

            let threadBasicInfo = convertThreadInfoToThreadBasicInfo(thinfo)

            if threadBasicInfo.flags != TH_FLAGS_IDLE {
                totCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            }
        } // for each thread
    }

    return (Int(threadCount), totCPU)
}

private func convertThreadInfoToThreadBasicInfo(_ threadInfo: [integer_t]) -> thread_basic_info {
    var result = thread_basic_info()

    result.user_time = time_value_t(seconds: threadInfo[0], microseconds: threadInfo[1])
    result.system_time = time_value_t(seconds: threadInfo[2], microseconds: threadInfo[3])
    result.cpu_usage = threadInfo[4]
    result.policy = threadInfo[5]
    result.run_state = threadInfo[6]
    result.flags = threadInfo[7]
    result.suspend_count = threadInfo[8]
    result.sleep_time = threadInfo[9]

    return result
}

func getMemoryUsage() -> Double {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        return Double(taskInfo.resident_size)
    } else {
        print("Error getting memory"
        return 0.0
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
            let newData = data.sorted()[numOutliers ... (data.count - numOutliers - 1)]

            max = newData[0]
            min = newData[newData.count - 1]

            let dataSize = newData.count
            let middle = dataSize / 2

            if (dataSize % 2 == 0) {
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

struct RunResults {
    let numDocs: Int
    let docSize: Int
    let numOutliers: Int
    let time: DoubleDataBlock
    let networkSentBytes: DoubleDataBlock
    let networkReceivedBytes: DoubleDataBlock
    let cpu: DoubleDataBlock
    let memory: DoubleDataBlock
    let disk: DoubleDataBlock
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
            "threads": threads.toBson()
        ]
    }
}

class MetricsCollector {
    let timeSource: DispatchSourceTimer
    private var threadData: [Double] = []
    private var cpuData: [Double] = []
    private var memoryData: [Double] = []

    init(timeInterval: TimeInterval) {
        timeSource = DispatchSource.makeTimerSource()
        timeSource.schedule(deadline: .now(), repeating: timeInterval)
        timeSource.setEventHandler(handler: { [weak self] in
            let (numThreads, cpuPer) = cpuUsage()
            self?.threadData.append(Double(numThreads))
            self?.cpuData.append(cpuPer)
            self?.memoryData.append(getMemoryUsage())
        })
    }

    func resume() {
        threadData = []
        cpuData = []
        memoryData = []
        timeSource.resume()
    }

    func suspend() -> (Double, Double, Double) {
        timeSource.suspend()
        return (threadData.reduce(0.0, +) / Double(threadData.count),
                cpuData.reduce(0.0, +) / Double(cpuData.count),
                memoryData.reduce(0.0, +) / Double(memoryData.count)))
    }
}
