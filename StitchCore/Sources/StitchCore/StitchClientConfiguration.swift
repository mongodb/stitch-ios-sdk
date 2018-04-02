/**
 * :nodoc:
 * Properties representing the configuration of a client that can communicate with MongoDB Stitch.
 */
public protocol StitchClientConfiguration {
    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    var baseURL: String { get }

    /**
     * The underlying storage for persisting authentication and app state.
     */
    var storage: Storage { get }

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
     */
    var transport: Transport { get }
}

/**
 * :nodoc:
 * The implementation of `StitchClientConfiguration`.
 */
public struct StitchClientConfigurationImpl: StitchClientConfiguration, Buildee {
    /**
     * The builder type that can build this client configuration.
     */
    public typealias TBuilder = StitchClientConfigurationBuilderImpl

    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public let baseURL: String

    /**
     * The underlying storage for authentication info.
     */
    public let storage: Storage

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
     */
    public let transport: Transport

    /**
     * Initializes this configuration by accepting a `StitchClientConfigurationBuilderImpl`.
     *
     * - throws: `StitchClientConfigurationError` if the builder is missing any properties.
     */
    public init(_ builder: TBuilder) throws {
        guard let baseURL = builder.baseURL else {
            throw StitchClientConfigurationError.missingBaseURL
        }

        guard let storage = builder.storage else {
            throw StitchClientConfigurationError.missingStorage
        }

        guard let transport = builder.transport else {
            throw StitchClientConfigurationError.missingTransport
        }

        self.baseURL = baseURL
        self.storage = storage
        self.transport = transport
    }
}

/**
 * :nodoc:
 * An error that a Stitch client configuration can throw if it is missing certain properties.
 */
public enum StitchClientConfigurationError: Error {
    case missingBaseURL
    case missingStorage
    case missingTransport
}

/**
 * :nodoc:
 * A protocol defining the configuration properties necessary to build a `StitchClientConfiguration`.
 */
public protocol StitchClientConfigurationBuilder {
    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    var baseURL: String? { get }

    /**
     * The underlying storage for authentication info.
     */
    var storage: Storage? { get }

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
     */
    var transport: Transport? { get }
}

/**
 * :nodoc:
 * A builder that can build a `StitchDocRequest` object.
 */
public struct StitchClientConfigurationBuilderImpl: StitchClientConfigurationBuilder, Builder {
    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public var baseURL: String?

    /**
     * The underlying storage for authentication info.
     */
    public var storage: Storage?

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
     */
    public var transport: Transport?

    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchClientConfigurationImpl

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchClientConfigurationBuilderImpl) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchClientConfiguration`.
     */
    public func build() throws -> TBuildee {
        return try StitchClientConfigurationImpl.init(self)
    }
}
