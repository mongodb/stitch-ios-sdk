import Foundation

/**
 * Properties representing the configuration of a client that communicate with a particular MongoDB Stitch application.
 */
public class StitchAppClientConfiguration: StitchClientConfiguration {
    /**
     * The client app id of the Stitch application that this client is going to communicate with.
     */
    public let clientAppID: String

    /**
     * The name of the local application.
     */
    public let localAppName: String

    /**
     * The current version of the local application.
     */
    public let localAppVersion: String
    
    internal init(appClientConfiguration: StitchAppClientConfiguration) {
        self.clientAppID = appClientConfiguration.clientAppID
        self.localAppName = appClientConfiguration.localAppName
        self.localAppVersion = appClientConfiguration.localAppVersion
        super.init(clientConfiguration: appClientConfiguration)
    }
    
    internal init(clientConfiguration: StitchClientConfiguration,
                  clientAppID: String,
                  localAppName: String,
                  localAppVersion: String) {
        self.clientAppID = clientAppID
        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
        super.init(clientConfiguration: clientConfiguration)
    }
}

/**
 * An error that a Stitch app client configuration can throw if it is missing certain properties.
 */
public enum StitchAppClientConfigurationError: Error {
    case missingClientAppID
}

/**
 * A builder that can build a `StitchAppClientConfiguration` object. Use this class to prepare a builder to pass into
 * client initialization methods on the `Stitch` utility class.
 */
public class StitchAppClientConfigurationBuilder: StitchClientConfigurationBuilder {
    public internal(set) var clientAppID: String?
    public internal(set) var localAppName: String?
    public internal(set) var localAppVersion: String?
    
    /**
     * Returns a builder for a given client app ID.
     *
     * - parameter withClientAppID: the client app id of the app.
     * - returns: a builder for the given client app id.
     */
    public static func forApp(withClientAppID clientAppID: String) -> StitchAppClientConfigurationBuilder {
        return StitchAppClientConfigurationBuilder().with(clientAppID: clientAppID)

    }
    
    // The `with` functions from the inherited builder are explicitly included and overriden here
    // for the sake of API documentation completeness.
    
    /**
     * Sets the base URL of the Stitch server that the client will communicate with.
     */
    @discardableResult
    public override func with(baseURL: String) -> Self {
        self.baseURL = baseURL
        return self
    }
    
    /**
     * Sets the local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    @discardableResult
    public override func with(dataDirectory: URL) -> Self {
        self.dataDirectory = dataDirectory
        return self
    }
    
    /**
     * Sets the underlying storage for authentication info.
     */
    @discardableResult
    public override func with(storage: Storage) -> Self {
        self.storage = storage
        return self
    }
    
    /**
     * Sets the `Transport` that the client will use to make HTTP round trips to the Stitch server.
     */
    @discardableResult
    public override func with(transport: Transport) -> Self {
        self.transport = transport
        return self
    }
    
    /**
     * Sets the number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout will override this one.
     */
    @discardableResult
    public override func with(defaultRequestTimeout: TimeInterval) -> Self {
        self.defaultRequestTimeout = defaultRequestTimeout
        return self
    }

    /**
     * Sets the client app id of the Stitch application that this client is going to communicate with.
     */
    @discardableResult
    public func with(clientAppID: String) -> Self {
        self.clientAppID = clientAppID
        return self
    }

    /**
     * Sets the name of the local application.
     */
    @discardableResult
    public func with(localAppName: String) -> Self {
        self.localAppName = localAppName
        return self
    }

    /**
     * Sets he current version of the local application.
     */
    @discardableResult
    public func with(localAppVersion: String) -> Self {
        self.localAppVersion = localAppVersion
        return self
    }
    
    /**
     * Builds a `StitchAppClientConfiguration` with the builder's specified settings.
     *
     * - important: The `Stitch` utility class accepts a builder for its client initialization methods so that it can
     *   can add defaults for various internal properties, so in most cases you do not need to call this method.
     */
    public override func build() throws -> StitchAppClientConfiguration {
        guard let clientAppID = self.clientAppID else {
            throw StitchAppClientConfigurationError.missingClientAppID
        }

        if let appName = self.localAppName {
            self.localAppName = appName
        } else {
            self.localAppName = "unkown app name"
        }

        if let appVersion = self.localAppVersion {
            self.localAppVersion = appVersion
        } else {
            self.localAppVersion = "unknown app version"
        }
        
        return try StitchAppClientConfiguration.init(
            clientConfiguration: super.build(),
            clientAppID: clientAppID,
            localAppName: self.localAppName!,
            localAppVersion: self.localAppVersion!
        )
    }
}
