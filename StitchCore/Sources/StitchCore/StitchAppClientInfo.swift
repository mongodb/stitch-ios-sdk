/**
 * A struct providing basic information about a Stitch app client.
 */
public struct StitchAppClientInfo {
    /**
     * Initializes the `StitchAppClientInfo`.
     */
    public init(clientAppId: String,
                dataDirectory: String,
                localAppName: String,
                localAppVersion: String) {
        self.clientAppId = clientAppId
        self.dataDirectory = dataDirectory
        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
    }

    /**
     * The client app ID of the Stitch application that this client communicates with.
     */
    public let clientAppId: String
    
    /**
     * The local data directory for any attached instance of mobile MongoDB.
     */
    public let dataDirectory: String
    
    /**
     * The name of the local application.
     */
    public let localAppName: String
    
    /**
     * The current version of the local application.
     */
    public let localAppVersion: String
}
