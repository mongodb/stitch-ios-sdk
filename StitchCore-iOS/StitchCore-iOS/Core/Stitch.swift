// swiftlint:disable force_try
import Foundation
import StitchCore

/**
 * Singleton class with utility functions for initializing the MongoDB Stitch iOS SDK,
 * and for retrieving a `StitchAppClient`. Not meant to be instantiated.
 */
public class Stitch {
    /**
     * The version of this MongoDB Stitch iOS SDK, which will be reported to Stitch in device info.
     */
    public static let sdkVersion: String = "4.0.0-alpha0"

    private static let defaultBaseUrl: String = "https://stitch.mongodb.com"
    private static let userDefaultsName: String = "com.mongodb.stitch.sdk.UserDefaults"

    private static var appClients: [String: StitchAppClientImpl] = [:]

    private static var initialized: Bool = false
    private static var defaultClientAppId: String?

    internal static var localAppVersion: String?
    internal static var localAppName: String?

    // Privatize default initializer to prevent instantation.
    private init() { }

    /**
     * Initializes the MongoDB Stitch SDK. Must be called before initializing any Stitch clients.
     *
     * - throws: A `StitchInitializationError` if initialization fails for any reason.
     */
    public static func initialize() throws {
        try! StitchCore.sync(self) {
            guard !initialized else { return }

            if let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String {
                localAppName = appName
            } else {
                print("WARNING: Failed to get name of application, will not be sent to MongoDB Stitch in device info.")
            }
            if let appVersion = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String {
                localAppVersion = appVersion
            } else {
                print(
                    "WARNING: Failed to get version of application, will not be sent to MongoDB Stitch in device info."
                )
            }

            initialized = true
            print("Initialized MongoDB Stitch iOS SDK")
        }
    }

    /**
     * Retrieves the default StitchAppClient associated with the application.
     *
     * - returns: A StitchAppClient with the configuration specified when
     *            `initializeDefaultAppClient(:withConfigBuilder)` was called.
     * - throws: A `StitchInitializationError` if `initialize()` was never called, or if `initializeDefaultAppClient`
     *           was never called.
     */
    public static func getDefaultAppClient() throws -> StitchAppClient {
        return try! StitchCore.sync(self) {
            guard initialized else {
                throw StitchInitializationError.stitchNotInitialized
            }

            guard let clientAppId = defaultClientAppId,
                  let client = appClients[clientAppId] else {
                throw StitchInitializationError.defaultClientNotInitialized
            }
            return client
        }
    }

    /**
     * Retrieves the StitchAppClient associated with the provided client app ID.
     *
     * - returns: A StitchAppClient with the configuration specified when
     *            `initializeAppClient(:withConfigBuilder)` was called with
     *            a configuration that created a client for the provided client app ID.
     * - throws: A `StitchInitializationError` if `initialize()` was never called, or
     *           if `initializeAppClient(:withConfigBuilder)` was never called with a
     *           configuration that created a client for the provided client app ID.
     * - parameters:
     *     - forAppId: The client app ID of the app client to be retrieved.
     */
    public static func getAppClient(forAppId appId: String) throws -> StitchAppClient {
        return try! StitchCore.sync(self) {
            guard initialized else {
                throw StitchInitializationError.stitchNotInitialized
            }

            guard let client = appClients[appId] else {
                throw StitchInitializationError.clientNotInitialized(clientAppId: appId)
            }
            return client
        }
    }

    /**
     * Initializes the default StitchAppClient associated with the application.
     *
     * - parameters:
     *     - withConfigBuilder: a StitchAppClientConfigurationBuilder containing the configuration desired
     *       for the default StitchAppClient.
     * - returns: A StitchAppClient configured with the provided configuration.
     * - throws: A `StitchInitializationError if the provided configuation is missing a client app ID,
     *           if a default app client has already been initialized, or the provided configuration
     *           contains a client app ID for which a non-default StitchAppClient has already been created.
     */
    public static func initializeDefaultAppClient(
        withConfigBuilder configBuilder: StitchAppClientConfigurationBuilder) throws -> StitchAppClient {
        return try! StitchCore.sync(self) {
            guard initialized else {
                throw StitchInitializationError.stitchNotInitialized
            }

            guard let clientAppId = configBuilder.clientAppId, clientAppId != "" else {
                throw StitchInitializationError.clientAppIdNotSpecified
            }

            guard defaultClientAppId == nil else {
                throw StitchInitializationError.defaultClientAlreadyInitialized(clientAppId: defaultClientAppId!)
            }

            let client = try initializeAppClient(withConfigBuilder: configBuilder)
            defaultClientAppId = clientAppId
            return client
        }
    }

    /**
     * Initializes a new, non-default StitchAppClient associated with the application.
     *
     * - parameters:
     *     - withConfigBuilder: a StitchAppClientConfigurationBuilder containing the configuration desired
     *       for the new StitchAppClient.
     * - returns: A StitchAppClient configured with the provided configuration.
     * - throws: A `StitchInitializationError` if the provided configuation is missing a client app ID,
     *           or if an app client has already been initialized for the client app ID in the provided configuration.
     */
    public static func initializeAppClient(
        withConfigBuilder configBuilder: StitchAppClientConfigurationBuilder) throws -> StitchAppClient {
        return try! StitchCore.sync(self) {
            guard initialized else {
                throw StitchInitializationError.stitchNotInitialized
            }

            guard let clientAppId = configBuilder.clientAppId, clientAppId != "" else {
                throw StitchInitializationError.clientAppIdNotSpecified
            }

            guard appClients[clientAppId] == nil else {
                throw StitchInitializationError.clientAlreadyInitialized(clientAppId: clientAppId)
            }

            var finalConfigBuilder = configBuilder

            if configBuilder.storage == nil {
                let suiteName = "\(userDefaultsName).\(clientAppId)"
                guard let userDefaults = UserDefaults.init(suiteName: suiteName) else {
                    throw StitchInitializationError.userDefaultsFailure
                }
                finalConfigBuilder.storage = userDefaults
            }

            // STITCH-1346:
//            if configBuilder.dataDirectory == nil {
//                finalConfigBuilder.dataDirectory = "/some/default/data/directory"
//            }

            if configBuilder.transport == nil {
                finalConfigBuilder.transport = FoundationHTTPTransport.init()
            }

            if configBuilder.baseURL == nil {
                finalConfigBuilder.baseURL = defaultBaseUrl
            }

            if configBuilder.localAppName == nil {
                finalConfigBuilder.localAppName = localAppName
            }

            if configBuilder.localAppVersion == nil {
                finalConfigBuilder.localAppVersion = localAppVersion
            }

            let client = try StitchAppClientImpl.init(withConfig: finalConfigBuilder.build())
            appClients[clientAppId] = client
            return client
        }
    }
}

/**
 * An error related to the initialization of the Stitch SDK, initializing clients, or retrieving clients.
 */
public enum StitchInitializationError: Error {
    /**
     * An error indicating that `Stitch.initialize()` was never called.
     */
    case stitchNotInitialized

    /**
     * An error indiciating that `Stitch.initializeDefaultAppClient()` was never called.
     */
    case defaultClientNotInitialized

    /**
     * An error indicating that a default app client has already been initialized.
     * Contains a clientAppId string indicating the clientAppId of the already-initialized default client.
     */
    case defaultClientAlreadyInitialized(clientAppId: String)

    /**
     * An error indicating that retrieval of a client failed because a client with the provided clientAppId
     * was never initialized.
     */
    case clientNotInitialized(clientAppId: String)

    /**
     * An error indicating that a client with the provided clientAppId has already been initialized.
     */
    case clientAlreadyInitialized(clientAppId: String)

    /**
     * An error indicating that client initialization failed because a clientAppId was not specified in its
     * configuration.
     */
    case clientAppIdNotSpecified

    /**
     * An error indicating the client initialization failed because `UserDefaults` could not be initialized.
     * This typically means you've specified an invalid client app ID.
     */
    case userDefaultsFailure

    /**
     * A description of the error case.
     */
    public var localizedDescription: String {
        switch self {
        case .stitchNotInitialized:
            return "The Stitch SDK has not yet been initialized. Must call Stitch.initialize()"
        case .defaultClientNotInitialized:
            return "Default client has not yet been initialized."
        case .defaultClientAlreadyInitialized(let clientAppId):
            return "Default client can only be initialized once; currently to \(clientAppId)"
        case .clientNotInitialized(let clientAppId):
            return "Client for app \(clientAppId) has not yet been initialized."
        case .clientAlreadyInitialized(let clientAppId):
            return "Client for app \(clientAppId) has already been initialized"
        case .clientAppIdNotSpecified:
            return "clientAppId must be set to a non-empty string"
        case .userDefaultsFailure:
            return "Could not initialize UserDefaults to store authentication information for MongoDB Stitch"
        }
    }
}
