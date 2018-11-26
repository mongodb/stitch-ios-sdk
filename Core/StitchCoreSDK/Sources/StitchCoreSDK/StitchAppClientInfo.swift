import Foundation

/**
 * :nodoc:
 * A struct providing basic information about a Stitch app client.
 */
public struct StitchAppClientInfo {
    /**
     * Initializes the `StitchAppClientInfo`.
     */
    public init(clientAppID: String,
                dataDirectory: URL,
                localAppName: String,
                localAppVersion: String,
                networkMonitor: NetworkMonitor,
                authMonitor: AuthMonitor?) {
        self.clientAppID = clientAppID
        self.dataDirectory = dataDirectory
        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
        self.networkMonitor = networkMonitor
        self.authMonitor = authMonitor
    }

    /**
     * The client app id of the Stitch application that this client communicates with.
     */
    public let clientAppID: String

    /**
     * The local directory in which Stitch can store any data (e.g. MongoDB Mobile data directory).
     */
    public let dataDirectory: URL

    /**
     * The name of the local application.
     */
    public let localAppName: String

    /**
     * The current version of the local application.
     */
    public let localAppVersion: String

    /**
     The network monitor of the local application.
     */
    public let networkMonitor: NetworkMonitor

    /**
     The auth monitor of the local application.
     */
    public var authMonitor: AuthMonitor!
}
