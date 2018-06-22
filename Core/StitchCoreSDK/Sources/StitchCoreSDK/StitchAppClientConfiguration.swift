import Foundation

/**
 * Properties representing the configuration of a client that communicate with a particular MongoDB Stitch application.
 */
public class StitchAppClientConfiguration: StitchClientConfiguration {
    /**
     * The name of the local application.
     */
    public let localAppName: String?
    
    /**
     * The current version of the local application.
     */
    public let localAppVersion: String?
    
    /// assign to avoid force cast
    private var _builder: StitchAppClientConfigurationBuilder
    override public var builder: StitchAppClientConfigurationBuilder {
        return _builder
    }
    
    internal init(builder: StitchAppClientConfigurationBuilder) {
        self.localAppName = builder.localAppName
        self.localAppVersion = builder.localAppVersion
        
        self._builder = builder
        super.init(builder: builder)
    }
}

/**
 * A builder that can build a `StitchAppClientConfiguration` object. Use this class to prepare a builder to pass into
 * client initialization methods on the `Stitch` utility class.
 */
public class StitchAppClientConfigurationBuilder: StitchClientConfigurationBuilder {
    public internal(set) var localAppName: String?
    public internal(set) var localAppVersion: String?
    
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
    public override func build() -> StitchAppClientConfiguration {
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
        
        return StitchAppClientConfiguration.init(
            builder: self
        )
    }
}
