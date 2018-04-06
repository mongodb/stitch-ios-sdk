import Foundation

/**
 * A struct providing basic information about a Stitch app client.
 */
public struct StitchAppClientInfo {
    /**
     * Initializes the `StitchAppClientInfo`.
     */
    public init(clientAppId: String,
                dataDirectory: URL?,
                localAppName: String,
                localAppVersion: String) {
        self.clientAppId = clientAppId
        self.dataDirectory = dataDirectory
        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
    }

    /**
     * The client app id of the Stitch application that this client communicates with.
     */
    public let clientAppId: String

    /**
     * The local directory in which Stitch can store any data (e.g. MongoDB Mobile data directory).
     */
    public let dataDirectory: URL?

    /**
     * The name of the local application.
     */
    public let localAppName: String

    /**
     * The current version of the local application.
     */
    public let localAppVersion: String
}
