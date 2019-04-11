import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

protocol SyncPerformanceTestContext {
    var dbName: String { get }
    var collName: String { get }
    var userId: String { get }
    var client: StitchAppClient { get }
    var mongoClient: RemoteMongoClient { get }
    var coll: RemoteMongoCollection<Document> { get }
    var harness: SyncPerformanceIntTestHarness { get }
    var streamJoiner: StreamJoiner { get }
    var joiner: ThrowingCallbackJoiner { get }

    init(harness: SyncPerformanceIntTestHarness) throws

    func tearDown() throws
}

extension SyncPerformanceTestContext {
    func runSingleIteration(numDocs: Int,
                            docSize: Int,
                            testDefinition: TestDefinition,
                            setup: SetupDefinition,
                            teardown: TeardownDefinition) throws -> IterationResult {
        // Perform custom setup if it exists
        try setup(self, numDocs, docSize)

        // Get starting values for disk space and time
        let timeBefore = Date().timeIntervalSince1970
        let networkReceivedBefore = Double(harness.networkTransport.bytesDownloaded)
        let networkSentBefore = Double(harness.networkTransport.bytesUploaded)

        var systemAttributes =
            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        let freeSpaceBefore =
            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0

        // Start repeating task
        let timeInterval = SyncPerformanceTestUtils.configuredDataGranularity / 1000.0
        let metricsCollector = MetricsCollector(timeInterval: timeInterval)
        metricsCollector.resume()

        // Run the desired function
        try testDefinition(self, numDocs, docSize)

        // Get finish time
        let timeMs = Double(Date().timeIntervalSince1970 - timeBefore) * 1000

        // Get the point-in-time measurements
        let pointInTimeMetrics = metricsCollector.suspend()

        // Append remaining values
        let networkReceived = Double(harness.networkTransport.bytesDownloaded) - networkReceivedBefore
        let networkSent = Double(harness.networkTransport.bytesUploaded) - networkSentBefore

        systemAttributes =
            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        let freeSpaceAfter =
            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
        let diskUsed = freeSpaceBefore - freeSpaceAfter

        // Perform custom taredown if specified
        try teardown(self, numDocs, docSize)

        return IterationResult(executionTimeMs: timeMs,
                               networkSentBytes: networkSent,
                               networkReceivedBytes: networkReceived,
                               cpuUsagePercent: pointInTimeMetrics.cpuData,
                               memoryUsageBytes: pointInTimeMetrics.memoryData,
                               diskUsageBytes: diskUsed,
                               activeThreadCount: pointInTimeMetrics.threadData)
    }

    func waitForAllStreamsOpen() {
        while !coll.sync.proxy.dataSynchronizer.allStreamsAreOpen {
            print("waiting for all streams to open before doing sync pass")
            sleep(1)
        }
    }

    func streamAndSync() throws {
        if  harness.networkMonitor.state == .connected {
            // add the stream joiner as a delegate of the stream so we can wait for events
            if let iCSDel = coll.sync.proxy
                .dataSynchronizer
                .instanceChangeStreamDelegate,
                let nsConfig = iCSDel[MongoNamespace(databaseName: dbName, collectionName: collName)] {
                nsConfig.add(streamDelegate: streamJoiner)
                streamJoiner.streamState = nsConfig.state
            }

            // wait for streams to open
            waitForAllStreamsOpen()
        }
        _ = try coll.sync.proxy.dataSynchronizer.doSyncPass()
    }

    func powerCycleDevice() throws {
        try coll.sync.proxy.dataSynchronizer.reloadConfig()
        if streamJoiner.streamState != nil {
            streamJoiner.wait(forState: .closed)
        }
    }

    func clearLocalDB() throws {
        // swiftlint:disable force_cast
        coll.sync.desync(ids: coll.sync.syncedIds().map({$0.value}))
        try CoreLocalMongoDBService.shared.localInstances.forEach { client in
            do {
                try client.listDatabases().forEach {
                    try? client.db($0["name"] as! String).drop()
                }
            } catch {
                throw "Could not drop databases in ProductionPerformanceTestContext.teardown()"
            }
        }
        // swiftlint:enable force_cast
    }
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
        print("Error getting memory")
        return 0.0
    }
}

internal struct PointInTimeMetrics {
    let threadData: Double
    let cpuData: Double
    let memoryData: Double
}

internal class MetricsCollector {
    let timeSource: DispatchSourceTimer
    private var threadData: [Double] = []
    private var cpuData: [Double] = []
    private var memoryData: [Double] = []

    init(timeInterval: TimeInterval) {
        timeSource = DispatchSource.makeTimerSource()
        timeSource.schedule(deadline: .now(), repeating: timeInterval)
        timeSource.setEventHandler(handler: { [weak self] in
            guard let self = self else { return }
            let (numThreads, cpuPer) = cpuUsage()
            self.threadData.append(Double(numThreads))
            self.cpuData.append(cpuPer)
            self.memoryData.append(getMemoryUsage())
        })
    }

    func resume() {
        threadData = []
        cpuData = []
        memoryData = []
        timeSource.resume()
    }

    func suspend() -> PointInTimeMetrics {
        timeSource.cancel()
        return PointInTimeMetrics(threadData: threadData.reduce(0.0, +) / Double(threadData.count),
                                  cpuData: cpuData.reduce(0.0, +) / Double(cpuData.count),
                                  memoryData: memoryData.reduce(0.0, +) / Double(memoryData.count))
    }
}

// Helper functions to get usage stats
// Solution taken from: https://stackoverflow.com/questions/8223348/ios-get-cpu-usage-from-application
private func cpuUsage() -> (Int, Double) {
    var kernelReturn: kern_return_t
    var taskInfoCount: mach_msg_type_number_t

    taskInfoCount = mach_msg_type_number_t(TASK_INFO_MAX)
    var tinfo = [integer_t](repeating: 0, count: Int(taskInfoCount))

    kernelReturn = task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), &tinfo, &taskInfoCount)
    if kernelReturn != KERN_SUCCESS {
        return (-1, -1.0)
    }

    var threadList: thread_act_array_t? = UnsafeMutablePointer(mutating: [thread_act_t]())
    var threadCount: mach_msg_type_number_t = 0
    defer {
        if let threadList = threadList {
            vm_deallocate(mach_task_self_, vm_address_t(UnsafePointer(threadList).pointee), vm_size_t(threadCount))
        }
    }
    kernelReturn = task_threads(mach_task_self_, &threadList, &threadCount)

    if kernelReturn != KERN_SUCCESS {
        return (-1, -1.0)
    }

    var totCPU: Double = 0
    if let threadList = threadList {
        for iter in 0 ..< Int(threadCount) {
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            var thinfo = [integer_t](repeating: 0, count: Int(threadInfoCount))
            kernelReturn = thread_info(threadList[iter], thread_flavor_t(THREAD_BASIC_INFO),
                                       &thinfo, &threadInfoCount)
            if kernelReturn != KERN_SUCCESS {
                return (-1, -1.0)
            }

            let threadBasicInfo = convertThreadInfoToThreadBasicInfo(thinfo)
            if threadBasicInfo.flags != TH_FLAGS_IDLE {
                totCPU += (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            }
        }
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
