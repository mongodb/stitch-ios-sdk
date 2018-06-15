import Foundation
import mongo_embedded

/// Settings for constructing a `MongoClient`
public struct MongoClientSettings {
    /// the database path to use
    public let dbPath: String

    /// public member-wise initializer
    public init(dbPath: String) {
        self.dbPath = dbPath
    }
}

/// Errors associated with `MongoMobile`.
public enum MongoMobileError: LocalizedError {
    case invalidClient()
    case invalidInstance(message: String)
    case invalidLibrary()
    case instanceDropError(message: String)
    case cleanupError(message: String)

    /// a string to be printed out when the error is thrown
    public var errorDescription: String? {
        switch self {
        case let .invalidInstance(message),
            let .instanceDropError(message),
            let .cleanupError(message):
            return message
        default:
            return nil
        }
    }
}

/// Prints a log statement in the format `[component] message`.
private func mongo_mobile_log_callback(userDataPtr: UnsafeMutableRawPointer?,
                                       messagePtr: UnsafePointer<Int8>?,
                                       componentPtr: UnsafePointer<Int8>?,
                                       contextPtr: UnsafePointer<Int8>?,
                                       severityPtr: Int32) {
    let message = messagePtr != nil ? String(cString: messagePtr!) : ""
    let component = componentPtr != nil ? String(cString: componentPtr!) : ""
    print("[\(component)] \(message)")
}

/// Given an `OpaquePointer` to a `mongo_embedded_v1_status`, get the status's explanation.
private func getStatusExplanation(_ status: OpaquePointer?) -> String {
    return String(cString: mongo_embedded_v1_status_get_explanation(status))
}

/// A class containing static methods for working with MongoMobile.
public class MongoMobile {
    private static var libraryInstance: OpaquePointer?
    private static var embeddedInstances = [String: OpaquePointer]()

    /**
     * Perform required operations to initialize the embedded server.
     */
    public static func initialize() throws {
        MongoSwift.initialize()

        let status = mongo_embedded_v1_status_create()
        var initParams = mongo_embedded_v1_init_params()
        initParams.log_callback = mongo_mobile_log_callback
        initParams.log_flags = UInt64(MONGO_EMBEDDED_V1_LOG_CALLBACK.rawValue)

        guard let instance = mongo_embedded_v1_lib_init(&initParams, status) else {
            throw MongoMobileError.invalidInstance(message: getStatusExplanation(status))
        }

        libraryInstance = instance
    }

    /**
     * Perform required operations to clean up the embedded server.
     */
    public static func close() throws {
        let status = mongo_embedded_v1_status_create()
        for (_, instance) in embeddedInstances {
            let result = mongo_embedded_v1_instance_destroy(instance, status)
            if result == MONGO_EMBEDDED_V1_ERROR_EXCEPTION.rawValue {
                throw MongoMobileError.instanceDropError(message: getStatusExplanation(status))
            }
        }

        let result = mongo_embedded_v1_lib_fini(libraryInstance, status)
        if result == MONGO_EMBEDDED_V1_ERROR_EXCEPTION.rawValue {
            throw MongoMobileError.cleanupError(message: getStatusExplanation(status))
        }

        MongoSwift.cleanup()
    }

    /**
     * Create a new `MongoClient` for the database indicated by `dbPath` in
     * the passed in settings.
     *
     * - Parameters:
     *   - settings: required settings for client creation
     *
     * - Returns: a new `MongoClient`
     */
    public static func create(_ settings: MongoClientSettings) throws -> MongoClient {
        let status = mongo_embedded_v1_status_create()
        var instance: OpaquePointer?
        if let cachedInstance = embeddedInstances[settings.dbPath] {
            instance = cachedInstance
        } else {
            // get the configuration as a JSON string
            let configuration = [
                "storage": [
                    "dbPath": settings.dbPath
                ]
            ]
            let configurationData = try JSONSerialization.data(withJSONObject: configuration)
            let configurationString = String(data: configurationData, encoding: .utf8)

            guard let library = libraryInstance else {
                throw MongoMobileError.invalidLibrary()
            }

            guard let capiInstance = mongo_embedded_v1_instance_create(library, configurationString, status) else {
                throw MongoMobileError.invalidInstance(message: getStatusExplanation(status))
            }

            instance = capiInstance
            embeddedInstances[settings.dbPath] = instance
        }

        guard let capiClient = mongo_embedded_v1_mongoc_client_create(instance) else {
            throw MongoMobileError.invalidClient()
        }

        return MongoClient(fromPointer: capiClient)
    }
}
