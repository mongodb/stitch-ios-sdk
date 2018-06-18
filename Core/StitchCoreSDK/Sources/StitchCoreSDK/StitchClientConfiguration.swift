import Foundation

/**
 * :nodoc:
 * Properties representing the configuration of a client that can communicate with MongoDB Stitch.
 */
public class StitchClientConfiguration {
    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public let baseURL: String

    /**
     * The local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    public let dataDirectory: URL

    /**
     * The underlying storage for persisting authentication and app state.
     */
    public let storage: Storage

    /**
     * The `Transport` that the client will use to make HTTP round trips to the Stitch server.
     */
    public let transport: Transport

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout will override this one.
     */
    public let defaultRequestTimeout: TimeInterval
    
    internal init(clientConfiguration: StitchClientConfiguration) {
        self.baseURL = clientConfiguration.baseURL
        self.dataDirectory = clientConfiguration.dataDirectory
        self.storage = clientConfiguration.storage
        self.transport = clientConfiguration.transport
        self.defaultRequestTimeout = clientConfiguration.defaultRequestTimeout
    }
    
    internal init(baseURL: String,
                  dataDirectory: URL,
                  storage: Storage,
                  transport: Transport,
                  defaultRequestTimeout: TimeInterval) {
        self.baseURL = baseURL
        self.dataDirectory = dataDirectory
        self.storage = storage
        self.transport = transport
        self.defaultRequestTimeout = defaultRequestTimeout
    }
}

/**
 * :nodoc:
 * An error that a Stitch client configuration can throw if it is missing certain properties.
 */
public enum StitchClientConfigurationError: Error {
    case missingBaseURL
    case missingDataDirectory
    case missingStorage
    case missingTransport
    case missingDefaultRequestTimeout
}

/**
 * :nodoc:
 * A builder that can build a `StitchClientConfiguration`.
 */
public class StitchClientConfigurationBuilder {
    public internal(set) var baseURL: String?
    public internal(set) var dataDirectory: URL?
    public internal(set) var storage: Storage?
    public internal(set) var transport: Transport?
    public internal(set) var defaultRequestTimeout: TimeInterval?
    
    /**
     * Sets the base URL of the Stitch server that the client will communicate with.
     */
    @discardableResult
    public func with(baseURL: String) -> Self {
        self.baseURL = baseURL
        return self
    }

    /**
     * Sets the local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    @discardableResult
    public func with(dataDirectory: URL) -> Self {
        self.dataDirectory = dataDirectory
        return self
    }

    /**
     * Sets the underlying storage for authentication info.
     */
    @discardableResult
    public func with(storage: Storage) -> Self {
        self.storage = storage
        return self
    }

    /**
     * Sets the `Transport` that the client will use to make HTTP round trips to the Stitch server.
     */
    @discardableResult
    public func with(transport: Transport) -> Self {
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
    public func with(defaultRequestTimeout: TimeInterval) -> Self {
        self.defaultRequestTimeout = defaultRequestTimeout
        return self
    }
    
    public init() { }
    
    init(clientConfiguration: StitchClientConfiguration) {
        self.baseURL = clientConfiguration.baseURL
        self.dataDirectory = clientConfiguration.dataDirectory
        self.storage = clientConfiguration.storage
        self.transport = clientConfiguration.transport
        self.defaultRequestTimeout = clientConfiguration.defaultRequestTimeout
    }
    
    public func build() throws -> StitchClientConfiguration {
        guard let baseURL = self.baseURL else {
            throw StitchClientConfigurationError.missingBaseURL
        }

        guard let dataDirectory = self.dataDirectory else {
            throw StitchClientConfigurationError.missingDataDirectory
        }

        guard let storage = self.storage else {
            throw StitchClientConfigurationError.missingStorage
        }

        guard let transport = self.transport else {
            throw StitchClientConfigurationError.missingTransport
        }

        guard let defaultRequestTimeout = self.defaultRequestTimeout else {
            throw StitchClientConfigurationError.missingDefaultRequestTimeout
        }
        
        return StitchClientConfiguration.init(
            baseURL: baseURL,
            dataDirectory: dataDirectory,
            storage: storage,
            transport: transport,
            defaultRequestTimeout: defaultRequestTimeout
        )
    }
}
