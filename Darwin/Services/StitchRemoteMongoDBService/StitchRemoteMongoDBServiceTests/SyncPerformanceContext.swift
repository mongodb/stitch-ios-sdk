// swiftlint:disable force_try
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
import StitchCoreLocalMongoDBService
@testable import StitchRemoteMongoDBService

class SyncPerformanceContext {
    private(set) var client: StitchAppClient?
    private(set) var mongoClient: RemoteMongoClient?
    private(set) var coll: RemoteMongoCollection<Document>?

    private(set) var dbName = ""
    private(set) var collName = ""
    private(set) var userId = ""

    let joiner = ThrowingCallbackJoiner()
    let streamJoiner = StreamJoiner()
    let testParams: TestParams?
    let transport: FoundationInstrumentedHTTPTransport?
    let harness: SyncPerformanceIntTestHarness?

    init(harness: SyncPerformanceIntTestHarness,
         testParams: TestParams,
         transport: FoundationInstrumentedHTTPTransport) throws {
        self.testParams = testParams
        self.transport = transport
        self.harness = harness
        if testParams.stitchHostName == "https://stitch.mongodb.com" {
            print("PerfLog: Context: Initializing STITCH-Prod")
            dbName = harness.stitchTestDbName
            collName = harness.stitchTestCollName
            client = harness.outputClient
            mongoClient = harness.outputMongoClient
            coll = mongoClient?.db(dbName).collection(collName)
            print("PerfLog: Context: Finished initializing STITCH-Prod")
        } else {
            print("PerfLog: Context: Initializing STITCH-Local")
            dbName = ObjectId().oid
            collName = ObjectId().oid

            harness.setUp()
            let app = try! harness.createApp()
            _ = try! harness.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
            let svc = try! harness.addService(toApp: app.1, withType: "mongodb", withName: "mongodb1",
                                         withConfig: ServiceConfigs.mongodb(name: "mongodb1", uri: harness.mongodbUri))
            let rule = RuleCreator.mongoDb(database: dbName, collection: collName,
                                           roles: [RuleCreator.Role(read: true, write: true)],
                                           schema: RuleCreator.Schema())
            _ = try! harness.addRule(toService: svc.1, withConfig: rule)

            client = try! harness.appClient(forApp: app.0, withTransport: transport)
            client?.auth.login(withCredential: AnonymousCredential(), joiner.capture())
            let _: Any? = try joiner.value()
            userId = client?.auth.currentUser?.id ?? ""

            mongoClient = try! client?.serviceClient(fromFactory: remoteMongoClientFactory, withName: "mongodb1")
            coll = mongoClient?.db(dbName).collection(collName)
            print("PerfLog: Context: Finished Initializing STITCH-Local")
        }

        coll?.sync.proxy.dataSynchronizer.isSyncThreadEnabled = false
        coll?.sync.proxy.dataSynchronizer.stop() // Failing here occaisonally
        print("PerfLog: Context: Done with initialization")
    }

    func runSingleIteration(numDocs: Int,
                            docSize: Int,
                            testDefinition: TestDefinition,
                            setup: TestDefinition,
                            teardown: TestDefinition) throws -> IterationResult {
        // Perform custom setup if it exists
        try setup(self, numDocs, docSize)

        // Get starting values for disk space and time
        let timeBefore = Date().timeIntervalSince1970
        let networkReceivedBefore = Double(transport?.bytesDownloaded ?? 0)
        let networkSentBefore = Double(transport?.bytesUploaded ?? 0)

        var systemAttributes =
            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        let freeSpaceBefore =
            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0

        // Start repeating task
        let timeInterval = Double(testParams?.dataProbeGranularityMs ?? 500) / 1000.0
        let metricsCollector = MetricsCollector(timeInterval: timeInterval)
        metricsCollector.resume()

        // Run the desired function
        try testDefinition(self, numDocs, docSize)

        // Get finish time
        let timeMs = Double(Date().timeIntervalSince1970 - timeBefore) * 1000

        // Get the point-in-time measurements
        let pointInTimeMetrics = metricsCollector.suspend()

        // Append remaining values
        let networkReceived = Double(transport?.bytesDownloaded ?? 0) - networkReceivedBefore
        let networkSent = Double(transport?.bytesUploaded ?? 0) - networkSentBefore

        systemAttributes =
            try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
        let freeSpaceAfter =
            (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
        let diskUsed = freeSpaceBefore - freeSpaceAfter

        // Perform custom taredown if specified
        try teardown(self, numDocs, docSize)

        return IterationResult(time: timeMs,
                               networkSentBytes: networkSent,
                               networkReceivedBytes: networkReceived,
                               cpu: pointInTimeMetrics.cpuData,
                               memory: pointInTimeMetrics.memoryData,
                               disk: diskUsed,
                               threads: pointInTimeMetrics.threadData)
    }

    func tearDown() throws {
        guard let coll = coll else {
            throw "Colleciton not valid"
        }

        if testParams?.stitchHostName == "https://stitch.mongodb.com" {
             client?.callFunction(withName: "deleteAllAsSystemUser", withArgs: [], joiner.capture())
            let _: Any? = try joiner.value()
        }

        if coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate != nil {
            coll.sync.proxy.dataSynchronizer.instanceChangeStreamDelegate.stop()
        }

        // swiftlint:disable force_cast
        CoreLocalMongoDBService.shared.localInstances.forEach { client in
            try! client.listDatabases().forEach {
                try? client.db($0["name"] as! String).drop()
            }
        }
        // swiftlint:enable force_cast
    }

    func waitForAllStreamsOpen() {
        guard let coll = coll else {
            print("PerfLog: (waitForAllStreamsOpen) Coll is nil")
            return
        }
        while !coll.sync.proxy.dataSynchronizer.allStreamsAreOpen {
            print("waiting for all streams to open before doing sync pass")
            sleep(1)
        }
    }

    func streamAndSync() throws {
        guard let harness = harness, let coll = coll else {
            print("PerfLog: (streamAndSync) Harness / Coll is nil")
            return
        }
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
        guard let coll = coll else {
            print("PerfLog: (powerCycleDevice) Coll is nil")
            return
        }

        try coll.sync.proxy.dataSynchronizer.reloadConfig()
        if streamJoiner.streamState != nil {
            streamJoiner.wait(forState: .closed)
        }
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
    // swiftlint:disable large_tuple
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
