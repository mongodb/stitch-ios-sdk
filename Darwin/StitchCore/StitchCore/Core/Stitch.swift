import Foundation
import StitchCoreSDK

/**
 * Singleton class with static utility functions for initializing the MongoDB Stitch iOS SDK,
 * and for retrieving a `StitchAppClient`.
 */
public class Stitch {

    // MARK: Properties

    internal static var sdkVersion: String =
        Bundle(for: Stitch.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    private static let defaultBaseURL: String = "https://stitch.mongodb.com"
    private static let userDefaultsName: String = "com.mongodb.stitch.sdk.UserDefaults"
    private static let defaultDefaultRequestTimeout: TimeInterval = 15.0

    private static var appClients: [String: StitchAppClientImpl] = [:]

    private static var defaultClientAppID: String?

    internal static var localAppVersion: String? =
        Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String
    internal static var localAppName: String? =
        Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String

    // Privatize default initializer to prevent instantation.
    private init() { }

    // MARK: Global Initialization

    // MARK: Initializing Clients

    /**
     * Initializes the default StitchAppClient associated with the application.
     *
     * - parameters:
     *     - withConfigBuilder: a StitchAppClientConfigurationBuilder containing the configuration desired
     *       for the default StitchAppClient.
     * - returns: A StitchAppClient configured with the provided configuration.
     * - throws: A `StitchInitializationError` if the provided configuation is missing a client app id,
     *           if a default app client has already been initialized, or the provided configuration
     *           contains a client app id for which a non-default StitchAppClient has already been created.
     */
    public static func initializeDefaultAppClient(
        withClientAppID clientAppID: String,
        withConfig config: StitchAppClientConfiguration = StitchAppClientConfigurationBuilder().build()) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard defaultClientAppID == nil else {
            throw StitchInitializationError.defaultClientAlreadyInitialized(clientAppID: defaultClientAppID!)
        }

        let client = try initializeAppClient(withClientAppID: clientAppID, withConfig: config)
        defaultClientAppID = clientAppID
        return client
    }

    /**
     * Private helper function to generate a `StitchAppClientConfiguration` from a
     * `StitchAppClientConfigurationBuilder`. Fields not included in the provided builder will be populated with
     * sensible defaults.
     */
    private static func generateConfig(from config: StitchAppClientConfiguration,
                                       forClientAppID clientAppID: String) throws -> ImmutableStitchAppClientConfiguration {
        let finalConfigBuilder = config.builder

        if config.storage == nil {
            let suiteName = "\(userDefaultsName).\(clientAppID)"
            guard let userDefaults = UserDefaults.init(suiteName: suiteName) else {
                throw StitchInitializationError.userDefaultsFailure
            }
            finalConfigBuilder.with(storage: userDefaults)
        }

        if config.dataDirectory == nil {
            let dataDirectory = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true)
            if let dataDirectory = dataDirectory {
                finalConfigBuilder.with(dataDirectory: dataDirectory)
            }
        }

        if config.transport == nil {
            finalConfigBuilder.with(transport: FoundationHTTPTransport.init())
        }

        if config.defaultRequestTimeout == nil {
            finalConfigBuilder.with(defaultRequestTimeout: defaultDefaultRequestTimeout)
        }

        if config.baseURL == nil {
            finalConfigBuilder.with(baseURL: defaultBaseURL)
        }

        if config.localAppName == nil, let localAppName = localAppName {
            finalConfigBuilder.with(localAppName: localAppName)
        }

        if config.localAppVersion == nil, let localAppVersion = localAppVersion {
            finalConfigBuilder.with(localAppVersion: localAppVersion)
        }

        return try ImmutableStitchAppClientConfiguration(builder: finalConfigBuilder.build())
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
        withClientAppID clientAppID: String,
        withConfig config: StitchAppClientConfiguration = StitchAppClientConfigurationBuilder().build()) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard appClients[clientAppID] == nil else {
            throw StitchInitializationError.clientAlreadyInitialized(clientAppID: clientAppID)
        }

        let finalConfig = try generateConfig(from: config, forClientAppID: clientAppID)

        let client = try StitchAppClientImpl.init(withClientAppID: clientAppID, withConfig: finalConfig)
        appClients[clientAppID] = client
        return client
    }

    // MARK: Retrieving Clients

    /**
     * Retrieves the default StitchAppClient associated with the application.
     *
     * - returns: A StitchAppClient with the configuration specified when
     *            `initializeDefaultAppClient(:withConfigBuilder)` was called.
     *            If `initialize()` was never called, or if `initializeDefaultAppClient`
     *            was never called, this will return `nil`.
     */
    public static var defaultAppClient: StitchAppClient? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        guard let clientAppID = defaultClientAppID,
              let client = appClients[clientAppID] else {
            return nil
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
    public static func appClient(forAppID appID: String) throws -> StitchAppClient {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

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
