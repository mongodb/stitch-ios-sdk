import Foundation

internal final class StitchPushRouteParts {
    static let basePushRoute = StitchAppRouteParts.appRoute + "/push"
    static let pushProvidersRoute = basePushRoute + "/providers"
    static let registrationRoute = pushProvidersRoute + "/%@/registration"
}

public struct StitchPushRoutes {
    let clientAppID: String
    
    public init(clientAppID: String) {
        self.clientAppID = clientAppID
    }
    
    public func registrationRoute(forServiceName serviceName: String) -> String {
        return String.init(format: StitchPushRouteParts.registrationRoute, self.clientAppID, serviceName)
    }
}
