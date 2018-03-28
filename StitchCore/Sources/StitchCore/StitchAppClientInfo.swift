public struct StitchAppClientInfo {
    public init(clientAppId: String,
         dataDirectory: String,
         localAppName: String,
         localAppVersion: String) {
        self.clientAppId = clientAppId
        self.dataDirectory = dataDirectory
        self.localAppName = localAppName
        self.localAppVersion = localAppVersion
    }
    
    public let clientAppId: String
    public let dataDirectory: String
    public let localAppName: String
    public let localAppVersion: String
}
