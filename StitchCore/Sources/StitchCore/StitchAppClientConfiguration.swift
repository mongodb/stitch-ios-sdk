import Foundation

/**
 * Properties representing the configuration of a client that communicate with a particular MongoDB Stitch application.
 */
public protocol StitchAppClientConfiguration: StitchClientConfiguration {
    /**
     * The client app id of the Stitch application that this client is going to communicate with.
     */
    var clientAppId: String { get }

    /**
     * The name of the local application.
     */
    var localAppName: String { get }

    /**
     * The current version of the local application.
     */
    var localAppVersion: String { get }
}

/**
 * :nodoc:
 * The implementation of `StitchAppClientConfiguration`.
 */
public struct StitchAppClientConfigurationImpl: StitchAppClientConfiguration, Buildee {
    /**
     * The builder type that can build this configuration.
     */
    public typealias TBuilder = StitchAppClientConfigurationBuilder

    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public let baseURL: String

    /**
     * The local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    public let dataDirectory: URL

    /**
     * The underlying storage for authentication info.
     */
    public let storage: Storage

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
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

    /**
     * The client app id of the Stitch application that this client is going to communicate with.
     */
    public let clientAppId: String

    /**
     * The name of the local application.
     */
    public let localAppName: String

    /**
     * The current version of the local application.
     */
    public let localAppVersion: String

    /**
     * Initializes this configuration by accepting a `StitchAppClientConfigurationBuilder`.
     *
     * - throws: `StitchClientConfigurationError` or `StitchAppClientConfigurationError` if the builder is missing any
     *           properties.
     */
    public init(_ builder: TBuilder) throws {
        guard let clientAppId = builder.clientAppId else {
            throw StitchAppClientConfigurationError.missingClientAppId
        }

        self.clientAppId = clientAppId

        if let appName = builder.localAppName {
            self.localAppName = appName
        } else {
            self.localAppName = "unkown app name"
        }

        if let appVersion = builder.localAppVersion {
            self.localAppVersion = appVersion
        } else {
            self.localAppVersion = "unknown app version"
        }

        guard let baseURL = builder.baseURL else {
            throw StitchClientConfigurationError.missingBaseURL
        }

        guard let dataDirectory = builder.dataDirectory else {
            throw StitchClientConfigurationError.missingDataDirectory
        }

        guard let storage = builder.storage else {
            throw StitchClientConfigurationError.missingStorage
        }

        guard let transport = builder.transport else {
            throw StitchClientConfigurationError.missingTransport
        }
        
        guard let defaultRequestTimeout = builder.defaultRequestTimeout else {
            throw StitchClientConfigurationError.missingDefaultRequestTimeout
        }

        self.baseURL = baseURL
        self.dataDirectory = dataDirectory
        self.storage = storage
        self.transport = transport
        self.defaultRequestTimeout = defaultRequestTimeout
    }
}

/**
 * An error that a Stitch app client configuration can throw if it is missing certain properties.
 */
public enum StitchAppClientConfigurationError: Error {
    case missingClientAppId
}

/**
 * A builder that can build a `StitchAppClientConfiguration` object.
 */
public struct StitchAppClientConfigurationBuilder: StitchClientConfigurationBuilder, Builder {
    /**
     * :nodoc:
     * configuration type that this builder builds.
     */
    public typealias TBuildee = StitchAppClientConfigurationImpl

    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    public var baseURL: String?

    /**
     * The local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    public var dataDirectory: URL?

    /**
     * The underlying storage for authentication info.
     */
    public var storage: Storage?

    /**
     * The `Transport` that the client will use to make round trips to the Stitch server.
     */
    public var transport: Transport?
    
    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout will override this one.
     */
    public var defaultRequestTimeout: TimeInterval?

    /**
     * The client app id of the Stitch application that this client is going to communicate with.
     */
    public var clientAppId: String?

    /**
     * The name of the local application.
     */
    public var localAppName: String?

    /**
     * The current version of the local application.
     */
    public var localAppVersion: String?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchAppClientConfigurationBuilder) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchAppClientConfiguration`.
     */
    public func build() throws -> StitchAppClientConfigurationImpl {
        return try StitchAppClientConfigurationImpl.init(self)
    }
}
