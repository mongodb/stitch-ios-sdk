import Foundation
import StitchCoreSDK

public final class CoreFCMServicePushClient {
    private let pushClient: CoreStitchPushClient
    
    private static let registrationTokenField = "registrationToken"
    
    public init(pushClient: CoreStitchPushClient) {
        self.pushClient = pushClient
    }
    
    public func register(withRegistrationToken registrationToken: String) throws {
        try self.pushClient.registerInternal(
            withRegistrationInfo: [CoreFCMServicePushClient.registrationTokenField: registrationToken]
        )
    }
    
    public func deregister() throws {
        try self.pushClient.deregisterInternal()
    }
}
