import Foundation
import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
@testable import StitchCoreRemoteMongoDBService
@testable import StitchRemoteMongoDBService

internal class SyncPerformanceTestUtils {
    static let stitchProdHost = "https://stitch.mongodb.com"

    static private let defaultStitchHostName = "http://localhost:9090"
    static private let defaultNumIters = 3
    static private let defaultNumOutliers = 0
    static private let defaultHostName = "Local"
    static private let defaultDocSizes = [1024, 2048, 5120, 10240, 25600, 51200, 102400]
    static private let defaultNumDocs = [100, 500, 1000, 5000, 10000, 25000]
    static private let defaultDataGranularity = 1000.0
    static private let defaultOutputToStdout = true
    static private let defaultOutputToStitch = true
    static private let defaultPreserveRawOutput = false
    static private let defaultChangeEventPercentages = [0.0, 0.01, 0.1, 0.25, 0.5, 1.0]
    static private let defaultConflictPercentages = [0.0, 0.1, 0.5, 1.0]

    static let stitchHostName: String = {
        if !TEST_PERF_IOS_STITCH_HOST.isEmpty {
            if TEST_PERF_IOS_STITCH_HOST.lowercased() == "local" {
                return defaultStitchHostName
            } else if TEST_PERF_IOS_STITCH_HOST.lowercased() == "prod" {
                return "https://stitch.mongodb.com"
            }
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_STITCH_HOST"] {
            return param
        }
        return defaultStitchHostName
    }()

    static let numIters: Int = {
        if let param = Int(TEST_PERF_IOS_NUM_ITERS) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_NUM_ITERS"], let param = Int(paramStr) {
            return param
        }
        return defaultNumIters
    }()

    static let hostname: String = {
        if !TEST_PERF_IOS_HOSTNAME.isEmpty {
            return TEST_PERF_IOS_HOSTNAME
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_HOSTNAME"] {
            return param
        }
        return defaultHostName
    }()

    static let docSizes: [Int] = {
        if !TEST_PERF_IOS_DOC_SIZES.isEmpty {
            return stringToIntArr(TEST_PERF_IOS_DOC_SIZES)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_DOC_SIZES"] {
            return stringToIntArr(param)
        }
        return defaultDocSizes
    }()

    static let numDocs: [Int] = {
        if !TEST_PERF_IOS_NUM_DOCS.isEmpty {
            return stringToIntArr(TEST_PERF_IOS_NUM_DOCS)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_NUM_DOCS"] {
            return stringToIntArr(param)
        }
        return defaultNumDocs
    }()

    static let dataGranularity: Double = {
        if let param = Double(TEST_PERF_IOS_DATA_GRANULARITY) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_DATA_GRANULARITY"],
            let param = Double(paramStr) {
            return param
        }
        return defaultDataGranularity
    }()

    static let numOutliers: Int = {
        if let param = Int(TEST_PERF_IOS_NUM_OUTLIERS) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_NUM_OUTLIERS"],
            let param = Int(paramStr) {
            return param
        }
        return defaultNumOutliers
    }()

    static let shouldOutputToStdOut: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_STDOUT) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_STDOUT"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultOutputToStdout
    }()

    static let shouldOutputToStitch: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_STITCH) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_STITCH"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultOutputToStitch
    }()

    static let shouldOutputRaw: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_RAW) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_RAW"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultPreserveRawOutput
    }()

    static let changeEventPercentages: [Double] = {
        if !TEST_PERF_IOS_CHANGE_EVENT_PERCENTAGES.isEmpty {
            return stringToDoubleArr(TEST_PERF_IOS_CHANGE_EVENT_PERCENTAGES)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_CHANGE_EVENT_PERCENTAGES"] {
            return stringToDoubleArr(param)
        }
        return defaultChangeEventPercentages
    }()

    static let conflictPercentages: [Double] = {
        if !TEST_PERF_IOS_CONFLICT_PERCENTAGES.isEmpty {
            return stringToDoubleArr(TEST_PERF_IOS_CONFLICT_PERCENTAGES)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_CONFLICT_PERCENTAGES"] {
            return stringToDoubleArr(param)
        }
        return defaultConflictPercentages
    }()

    private static func stringToIntArr(_ str: String) -> [Int] {
        return str.split(separator: "-").map { Int($0) ?? 0 }
    }

    private static func stringToDoubleArr(_ str: String) -> [Double] {
        return str.split(separator: "-").map { Double($0) ?? 0.0 }
    }

    // To generate the documents, we use 7-character field names, and 54-character
    // strings as the field values. For each field, we expect 3 bytes of overhead.
    // (the BSON string type code, and two null terminators). This way, each field is 64
    // bytes. All of the doc sizes we use in this test are divisible by 64, so the number
    // of fields we generate in the document will be the desired document size divided by
    // 64. To account for the 5 byte overhead of defining a BSON document, and the 17 bytes
    static func generateDocuments(numDoc: Int, docSize: Int) -> [Document] {
        return (0..<numDoc).map { _ in
            var doc: Document = [self.generateRandomString(len: 7): self.generateRandomString(len: 32)]
            for _ in 0..<(docSize / 64 - 1) {
                doc[self.generateRandomString(len: 7)] = self.generateRandomString(len: 54)
            }
            return doc
        }
    }

    static func generateRandomString(len: Int) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwzyz1234567890"
        return String((0..<len).map { _ in alphabet.randomElement() ?? "x" })
    }

    // Custom assertEqual that throws so that the test fails if the assertion fails
    static func assertIntsEqualOrThrow(_ val1: Int, _ val2: Int, message: String) throws {
        if val1 == val2 { return } else {
            throw "(\(val1)) is not equal to (\(val2)): \(message)"
        }
    }

    static func insertToRemote(ctx: SyncPerformanceTestContext, numDocs: Int, docSize: Int) throws -> [BSONValue] {
        let docs = generateDocuments(numDoc: numDocs, docSize: docSize)
        let joiner = ThrowingCallbackJoiner()
        ctx.coll.insertMany(docs, joiner.capture())
        guard let result: RemoteInsertManyResult = try joiner.value() else {
            throw "Failed to insert \(numDocs) documents of size \(docSize) to remote"
        }

        try assertIntsEqualOrThrow(result.insertedIds.count, numDocs, message: "RemoteInstert.insertedIds.count")
        return result.insertedIds.map { $0.value }
    }

    static func performRemoteUpdate(ctx: SyncPerformanceTestContext, ids: [BSONValue]) throws {
        let joiner = ThrowingCallbackJoiner()
        ctx.coll.updateMany(filter: ["_id": ["$in": ids] as Document],
                            update: ["$set": ["newField": "remote"] as Document],
                            joiner.capture())

        guard let updateResult: RemoteUpdateResult = try joiner.value() else {
            throw "Failed to update \(ids.count) documents on remote"
        }

        try assertIntsEqualOrThrow(updateResult.matchedCount, ids.count, message: "RemoteUpdate.matchedCount")
        try assertIntsEqualOrThrow(updateResult.modifiedCount, ids.count, message: "RemoteUpdate.modifiedCount")

        ctx.coll.count(["newField": "remote"], joiner.capture())
        guard let countResult: Int = try joiner.value() else {
            throw "Failed to get count in SyncPerformanceTestUtils.performRemoteUpdate()"
        }
        try assertIntsEqualOrThrow(countResult, ids.count, message: "Remote documents updated")
    }

    static func performLocalUpdate(ctx: SyncPerformanceTestContext, ids: [BSONValue]) throws {
        let joiner = ThrowingCallbackJoiner()
        ctx.coll.sync.updateMany(filter: ["_id": ["$in": ids] as Document],
                                 update: ["$set": ["newField": "local"] as Document],
                                 options: nil, joiner.capture())

        guard let updateResult: SyncUpdateResult = try joiner.value() else {
            throw "Failed to update \(ids.count) documents on remote"
        }
        try assertIntsEqualOrThrow(updateResult.matchedCount, ids.count, message: "LocalUpdate.matchedCount")
        try assertIntsEqualOrThrow(updateResult.modifiedCount, ids.count, message: "LocalUpdate.modifiedCount")

        ctx.coll.sync.count(filter: ["newField": "local"], options: nil, joiner.capture())
        guard let countResult: Int = try joiner.value() else {
            throw "Failed to get count in SyncPerformanceTestUtils.performLocalUpdate()"
        }
        try assertIntsEqualOrThrow(countResult, ids.count, message: "Local documents updated")
    }

    static func assertLocalAndRemoteDBCount(ctx: SyncPerformanceTestContext, numDocs: Int) throws {
        let joiner = ThrowingCallbackJoiner()

        // Ensure the number of documents in the remote db is correct
        ctx.coll.count([:], options: nil, joiner.capture())
        guard let remoteCount: Int = try joiner.value() else {
            throw "Failed to get remoteDB count in assertLocalAndRemoteDBCount()"
        }
        try assertIntsEqualOrThrow(remoteCount, numDocs, message: "Number of remote documents")

        // ensure the number of documents in the local db is correct
        ctx.coll.sync.count(joiner.capture())
        guard let localCount: Int = try joiner.value() else {
            throw "Failed to get remoteDB count in assertLocalAndRemoteDBCount()"
        }
        try assertIntsEqualOrThrow(localCount, numDocs, message: "Number of remote documents")

        // Ensure the number of synced documents is correct
        ctx.coll.sync.syncedIds(joiner.capture())
        guard let syncedIdsResult: Set<AnyBSONValue> = try joiner.value() else {
            throw "Failed to get remoteDB count in assertLocalAndRemoteDBCount()"
        }
        try assertIntsEqualOrThrow(syncedIdsResult.count, numDocs, message: "Number of synced documents")
    }

    static func doSyncPass(ctx: SyncPerformanceTestContext) throws {
        // ctx.testNetworkMonitor.connectedState = true
        var iters = 0
        while !ctx.coll.sync.proxy.dataSynchronizer.allStreamsAreOpen {
            iters += 1
            if iters >= 1000 {
                throw "Streams never opened"
            }
            sleep(30)
        }
        guard try ctx.coll.sync.proxy.dataSynchronizer.doSyncPass() == true else {
            throw "Sync Pass Failed in doSyncPass()"
        }
    }
}
