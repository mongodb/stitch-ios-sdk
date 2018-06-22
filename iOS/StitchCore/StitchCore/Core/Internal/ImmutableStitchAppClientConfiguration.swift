import Foundation
import StitchCoreSDK

internal struct ImmutableStitchAppClientConfiguration {
    /**
     * The name of the local application.
     */
    let localAppName: String

    /**
     * The current version of the local application.
     */
    let localAppVersion: String

    /**
     * The base URL of the Stitch server that the client will communicate with.
     */
    let baseURL: String

    /**
     * The local directory in which Stitch can store any data (e.g. embedded MongoDB data directory).
     */
    let dataDirectory: URL

    /**
     * The underlying storage for persisting authentication and app state.
     */
    let storage: Storage

    /**
     * The `Transport` that the client will use to make HTTP round trips to the Stitch server.
     */
    let transport: Transport

    /**
     * The number of seconds that a `Transport` should spend by default on an HTTP round trip before failing with an
     * error.
     *
     * - important: If a request timeout was specified for a specific operation, for example in a function call, that
     *              timeout will override this one.
     */
    let defaultRequestTimeout: TimeInterval

    init(builder: StitchAppClientConfiguration) throws {
        guard let localAppName = builder.localAppName,
            let localAppVersion = builder.localAppVersion,
            let baseURL = builder.baseURL,
            let dataDirectory = builder.dataDirectory,
            let storage = builder.storage,
            let transport = builder.transport,
            let defaultRequestTimeout = builder.defaultRequestTimeout else {
            throw StitchClientConfigurationError.missingProperty
        }

        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
        self.baseURL = baseURL
        self.dataDirectory = dataDirectory
        self.storage = storage
        self.transport = transport
        self.defaultRequestTimeout = defaultRequestTimeout
    }
}
