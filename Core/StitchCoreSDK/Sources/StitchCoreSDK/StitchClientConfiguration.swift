import Foundation

protocol Buildee {
    associatedtype Builder
}

/**
 * :nodoc:
 * Properties representing the configuration of a client that can communicate with MongoDB Stitch.
 */
public class StitchClientConfiguration: Buildee {
    public typealias Builder = StitchClientConfigurationBuilder
    
    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public let baseURL: String?

    /**
     * The local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    public let dataDirectory: URL?

    /**
     * The underlying storage for persisting authentication and app state.
     */
    public let storage: Storage?

    /**
     * The `Transport` that the client will use to make HTTP round trips to the Stitch server.
     */
    public let transport: Transport?

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout will override this one.
     */
    public let defaultRequestTimeout: TimeInterval?
    
    /**
     * Builder object for this configuration
    */
    public var builder: Builder {
        return StitchClientConfigurationBuilder.init(clientConfiguration: self)
    }
    
    init(builder: StitchClientConfigurationBuilder) {
        self.baseURL = builder.baseURL
        self.dataDirectory = builder.dataDirectory
        self.storage = builder.storage
        self.transport = builder.transport
        self.defaultRequestTimeout = builder.defaultRequestTimeout
    }
}

/**
 * :nodoc:
 * An error that a Stitch client configuration can throw if it is missing certain properties.
 */
public enum StitchClientConfigurationError: Error {
    case missingProperty
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
    
    fileprivate init(clientConfiguration: StitchClientConfiguration) {
        self.baseURL = clientConfiguration.baseURL
        self.dataDirectory = clientConfiguration.dataDirectory
        self.storage = clientConfiguration.storage
        self.transport = clientConfiguration.transport
        self.defaultRequestTimeout = clientConfiguration.defaultRequestTimeout
    }
    
    public func build() -> StitchClientConfiguration {
        return StitchClientConfiguration.init(builder: self)
    }
}
