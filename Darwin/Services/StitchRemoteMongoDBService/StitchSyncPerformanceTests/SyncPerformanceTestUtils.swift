import Foundation
import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchCoreRemoteMongoDBService
import StitchRemoteMongoDBService

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

    static let configuredStitchHostName: String = {
        if !TEST_PERF_IOS_STITCH_HOST.isEmpty {
            return TEST_PERF_IOS_STITCH_HOST
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_STITCH_HOST"] {
            return param
        }
        return defaultStitchHostName
    }()

    static let configuredNumIters: Int = {
        if let param = Int(TEST_PERF_IOS_NUM_ITERS) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_NUM_ITERS"], let param = Int(paramStr) {
            return param
        }
        return defaultNumIters
    }()

    static let configuredHostname: String = {
        if !TEST_PERF_IOS_HOSTNAME.isEmpty {
            return TEST_PERF_IOS_HOSTNAME
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_HOSTNAME"] {
            return param
        }
        return defaultHostName
    }()

    static let configuredDocSizes: [Int] = {
        if !TEST_PERF_IOS_DOC_SIZES.isEmpty {
            return stringToIntArr(TEST_PERF_IOS_DOC_SIZES)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_DOC_SIZES"] {
            return stringToIntArr(param)
        }
        return defaultDocSizes
    }()

    static let configuredNumDocs: [Int] = {
        if !TEST_PERF_IOS_NUM_DOCS.isEmpty {
            return stringToIntArr(TEST_PERF_IOS_NUM_DOCS)
        } else if let param = ProcessInfo.processInfo.environment["PERF_IOS_NUM_DOCS"] {
            return stringToIntArr(param)
        }
        return defaultNumDocs
    }()

    static let configuredDataGranularity: Double = {
        if let param = Double(TEST_PERF_IOS_DATA_GRANULARITY) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_DATA_GRANULARITY"],
            let param = Double(paramStr) {
            return param
        }
        return defaultDataGranularity
    }()

    static let configuredNumOutliers: Int = {
        if let param = Int(TEST_PERF_IOS_NUM_OUTLIERS) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_NUM_OUTLIERS"],
            let param = Int(paramStr) {
            return param
        }
        return defaultNumOutliers
    }()

    static let configuredShouldOutputToStdOut: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_STDOUT) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_STDOUT"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultOutputToStdout
    }()

    static let configuredShouldOutputToStitch: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_STITCH) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_STITCH"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultOutputToStitch
    }()

    static let configuredShouldOutputRaw: Bool = {
        if let param = Bool(TEST_PERF_IOS_OUTPUT_RAW) {
            return param
        } else if let paramStr = ProcessInfo.processInfo.environment["PERF_IOS_OUTPUT_RAW"],
            let param = Bool(paramStr) {
            return param
        }
        return defaultPreserveRawOutput
    }()

    private static func stringToIntArr(_ str: String) -> [Int] {
        return str.split(separator: ",").map { Int($0) ?? 0 }
    }

    static func generateDocuments(numDoc: Int, docSize: Int) -> [Document] {
        return (0..<numDoc).map { _ in ["data": generateRandomString(len: docSize)] }
    }

    static func generateRandomString(len: Int) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwzyz1234567890"
        return String((0..<len).map { _ in alphabet.randomElement() ?? "x" })
    }
}
