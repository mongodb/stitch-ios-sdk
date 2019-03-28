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
                        var cpuDataIter: [Double] = []
                        var memoryDataIter: [Double] = []
                        var threadDataIter: [Double] = []

                        let timeBefore = Date().timeIntervalSince1970
                        var systemAttributes =
                            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                        let freeSpaceBefore =
                            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
//
                        let hostCPUInfo = hostCPULoadInfo()
                        print(hostCPUInfo?.cpu_ticks)
                        print(cpuUsage())

                        let timeSource = DispatchSource.makeTimerSource()
                        timeSource.schedule(deadline: .now(), repeating: 0.5)
                        timeSource.setEventHandler(handler: { [weak self] in
                            let (numThreads, cpuPer) = cpuUsage()
                            threadDataIter.append(Double(numThreads))
                            cpuDataIter.append(cpuPer)
                            memoryDataIter.append(100.0)
                            print("sup fellas")
                        })
                        timeSource.resume()

//                        let repeatTask = RepeatingTimer(timeInterval: 1)
//                        repeatTask.eventHandler = {
//                            let (numThreads, cpuPer) = cpuUsage()
//                            threadDataIter.append(Double(numThreads))
//                            cpuDataIter.append(cpuPer)
//                            memoryDataIter.append(100.0)
//                            print("sup fellas")
//                        }
//                        repeatTask.resume()

                        testDefinition(numDoc, docSize)

                        timeSource.cancel()
                        print(cpuDataIter.count)

                        // add in values
                        timeData.append(Double(Date().timeIntervalSince1970 - timeBefore))
                        networkSentData.append(10.0)
                        networkReceivedData.append(10.90)
                        systemAttributes =
                            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
                        let freeSpaceAfter =
                            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
                        diskData.append(freeSpaceBefore - freeSpaceAfter)

                        // Add averages of point-in-time measurements
                        print("numMeasurements: \(cpuDataIter.count)")
                        cpuData.append(cpuDataIter.reduce(0.0, +) / Double(cpuDataIter.count))
                        threadData.append(threadDataIter.reduce(0.0, +) / Double(threadDataIter.count))
                        memoryData.append(memoryDataIter.reduce(0.0, +) / Double(memoryDataIter.count))

                    }
                }
            }
        } catch (let err) {
            print(err)
        }
    }

    var mdbService: Apps.App.Services.Service!
    var mdbRule: RuleResponse!

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

private func hostCPULoadInfo() -> host_cpu_load_info? {

    let hostCPULoadInfoCount = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride

    var size = mach_msg_type_number_t(hostCPULoadInfoCount)
    let hostInfo = host_cpu_load_info_t.allocate(capacity: 1)

    let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: hostCPULoadInfoCount) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
    }

    if result != KERN_SUCCESS {
        print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
        return nil
    }
    let data = hostInfo.move()
    hostInfo.deallocate(capacity: 1)
    return data
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

class RepeatingTimer {

    let timeInterval: TimeInterval

    init(timeInterval: TimeInterval) {
        self.timeInterval = timeInterval
    }

    private lazy var timer: DispatchSourceTimer = {
        let timeSource = DispatchSource.makeTimerSource()
        timeSource.schedule(deadline: .now() + self.timeInterval, repeating: self.timeInterval)
        timeSource.setEventHandler(handler: { [weak self] in
            self?.eventHandler?()
        })
        return timeSource
    }()

    var eventHandler: (() -> Void)?

    private enum State {
        case suspended
        case resumed
    }

    private var state: State = .suspended

    deinit {
        timer.setEventHandler {}
        timer.cancel()
        /*
         If the timer is suspended, calling cancel without resuming
         triggers a crash. This is documented here https://forums.developer.apple.com/thread/15902
         */
        resume()
        eventHandler = nil
    }

    func resume() {
        if state == .resumed {
            return
        }
        state = .resumed
        timer.resume()
    }

    func suspend() {
        if state == .suspended {
            return
        }
        state = .suspended
        timer.suspend()
    }
}
