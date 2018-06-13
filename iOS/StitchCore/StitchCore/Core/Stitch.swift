import Foundation
import StitchCoreSDK

/**
 * Singleton class with utility functions for initializing the MongoDB Stitch iOS SDK,
 * and for retrieving a `StitchAppClient`. Not meant to be instantiated.
 */
public class Stitch {

    // MARK: Properties

    /**
     * The version of this MongoDB Stitch iOS SDK, which will be reported to Stitch in device info.
     */
    public static let sdkVersion: String = "4.0.0-alpha0"

    private static let defaultBaseURL: String = "https://stitch.mongodb.com"
    private static let userDefaultsName: String = "com.mongodb.stitch.sdk.UserDefaults"
    private static let defaultDefaultRequestTimeout: TimeInterval = 15.0

    private static var appClients: [String: StitchAppClientImpl] = [:]

    private static var initialized: Bool = false
    private static var defaultClientAppID: String?

    internal static var localAppVersion: String?
    internal static var localAppName: String?

    // Privatize default initializer to prevent instantation.
    private init() { }

    // MARK: Global Initialization

    /**
     * Initializes the MongoDB Stitch SDK. Must be called before initializing any Stitch clients.
     *
     * - throws: A `StitchInitializationError` if initialization fails for any reason.
     */
    public static func initialize() throws {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

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

    // MARK: Initializing Clients

    /**
     * Initializes the default StitchAppClient associated with the application.
     *
     * - parameters:
     *     - withConfigBuilder: a StitchAppClientConfigurationBuilder containing the configuration desired
     *       for the default StitchAppClient.
     * - returns: A StitchAppClient configured with the provided configuration.
     * - throws: A `StitchInitializationError if the provided configuation is missing a client app id,
     *           if a default app client has already been initialized, or the provided configuration
     *           contains a client app id for which a non-default StitchAppClient has already been created.
     */
    public static func initializeDefaultAppClient(
        withConfigBuilder configBuilder: StitchAppClientConfigurationBuilder) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard initialized else {
            throw StitchInitializationError.stitchNotInitialized
        }

        guard let clientAppID = configBuilder.clientAppID, clientAppID != "" else {
            throw StitchInitializationError.clientAppIDNotSpecified
        }

        guard defaultClientAppID == nil else {
            throw StitchInitializationError.defaultClientAlreadyInitialized(clientAppID: defaultClientAppID!)
        }

        let client = try initializeAppClient(withConfigBuilder: configBuilder)
        defaultClientAppID = clientAppID
        return client
    }

    /**
     * Private helper function to generate a `StitchAppClientConfiguration` from a
     * `StitchAppClientConfigurationBuilder`. Fields not included in the provided builder will be populated with
     * sensible defaults.
     */
    private static func generateConfig(fromBuilder configBuilder: StitchAppClientConfigurationBuilder,
                                       forClientAppID clientAppID: String) throws -> StitchAppClientConfiguration {
        let finalConfigBuilder = configBuilder

        if configBuilder.storage == nil {
            let suiteName = "\(userDefaultsName).\(clientAppID)"
            guard let userDefaults = UserDefaults.init(suiteName: suiteName) else {
                throw StitchInitializationError.userDefaultsFailure
            }
            finalConfigBuilder.with(storage: userDefaults)
        }

        if configBuilder.dataDirectory == nil {
            let dataDirectory = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true)
            if let dataDirectory = dataDirectory {
                finalConfigBuilder.with(dataDirectory: dataDirectory)
            }
        }

        if configBuilder.transport == nil {
            finalConfigBuilder.with(transport: FoundationHTTPTransport.init())
        }

        if configBuilder.defaultRequestTimeout == nil {
            finalConfigBuilder.with(defaultRequestTimeout: defaultDefaultRequestTimeout)
        }

        if configBuilder.baseURL == nil {
            finalConfigBuilder.with(baseURL: defaultBaseURL)
        }

        if configBuilder.localAppName == nil, let localAppName = localAppName {
            finalConfigBuilder.with(localAppName: localAppName)
        }

        if configBuilder.localAppVersion == nil, let localAppVersion = localAppVersion {
            finalConfigBuilder.with(localAppVersion: localAppVersion)
        }

        return try finalConfigBuilder.build()
    }

    /**
     * Initializes a new, non-default StitchAppClient associated with the application.
     *
     * - parameters:
     *     - withConfigBuilder: a StitchAppClientConfigurationBuilder containing the configuration desired
     *       for the new StitchAppClient.
     * - returns: A StitchAppClient configured with the provided configuration.
     * - throws: A `StitchInitializationError` if the provided configuation is missing a client app id,
     *           or if an app client has already been initialized for the client app id in the provided configuration.
     */
    public static func initializeAppClient(
        withConfigBuilder configBuilder: StitchAppClientConfigurationBuilder) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard initialized else {
            throw StitchInitializationError.stitchNotInitialized
        }

        guard let clientAppID = configBuilder.clientAppID, clientAppID != "" else {
            throw StitchInitializationError.clientAppIDNotSpecified
        }

        guard appClients[clientAppID] == nil else {
            throw StitchInitializationError.clientAlreadyInitialized(clientAppID: clientAppID)
        }

        let finalConfig = try generateConfig(fromBuilder: configBuilder, forClientAppID: clientAppID)

        let client = try StitchAppClientImpl.init(withConfig: finalConfig)
        appClients[clientAppID] = client
        return client
    }

    // MARK: Retrieving Clients

    /**
     * Retrieves the default StitchAppClient associated with the application.
     *
     * - returns: A StitchAppClient with the configuration specified when
     *            `initializeDefaultAppClient(:withConfigBuilder)` was called.
     * - throws: A `StitchInitializationError` if `initialize()` was never called, or if `initializeDefaultAppClient`
     *           was never called.
     */
    public static func getDefaultAppClient() throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard initialized else {
            throw StitchInitializationError.stitchNotInitialized
        }

        guard let clientAppID = defaultClientAppID,
              let client = appClients[clientAppID] else {
            throw StitchInitializationError.defaultClientNotInitialized
        }
        return client
    }

    /**
     * Retrieves the StitchAppClient associated with the provided client app id.
     *
     * - returns: A StitchAppClient with the configuration specified when
     *            `initializeAppClient(:withConfigBuilder)` was called with
     *            a configuration that created a client for the provided client app id.
     * - throws: A `StitchInitializationError` if `initialize()` was never called, or
     *           if `initializeAppClient(:withConfigBuilder)` was never called with a
     *           configuration that created a client for the provided client app id.
     * - parameters:
     *     - forAppID: The client app id of the app client to be retrieved.
     */
    public static func getAppClient(forAppID appID: String) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard initialized else {
            throw StitchInitializationError.stitchNotInitialized
        }

        guard let client = appClients[appID] else {
            throw StitchInitializationError.clientNotInitialized(clientAppID: appID)
        }
        return client
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
     * Contains a clientAppID string indicating the clientAppID of the already-initialized default client.
     */
    case defaultClientAlreadyInitialized(clientAppID: String)

    /**
     * An error indicating that retrieval of a client failed because a client with the provided clientAppID
     * was never initialized.
     */
    case clientNotInitialized(clientAppID: String)

    /**
     * An error indicating that a client with the provided clientAppID has already been initialized.
     */
    case clientAlreadyInitialized(clientAppID: String)

    /**
     * An error indicating that client initialization failed because a clientAppID was not specified in its
     * configuration.
     */
    case clientAppIDNotSpecified

    /**
     * An error indicating the client initialization failed because `UserDefaults` could not be initialized.
     * This typically means you've specified an invalid client app id.
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
        case .defaultClientAlreadyInitialized(let clientAppID):
            return "Default client can only be initialized once; currently to \(clientAppID)"
        case .clientNotInitialized(let clientAppID):
            return "Client for app \(clientAppID) has not yet been initialized."
        case .clientAlreadyInitialized(let clientAppID):
            return "Client for app \(clientAppID) has already been initialized"
        case .clientAppIDNotSpecified:
            return "clientAppID must be set to a non-empty string"
        case .userDefaultsFailure:
            return "Could not initialize UserDefaults to store authentication information for MongoDB Stitch"
        }
    }
}
