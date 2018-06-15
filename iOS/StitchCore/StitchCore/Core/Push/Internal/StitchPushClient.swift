import Foundation
import MongoSwift
import StitchCoreSDK

/**
 * StitchPushClient is used to register for push notifications.
 */
public protocol StitchPushClient: CoreStitchPushClient {
    func register(withRegistrationInfo registrationInfo: Document,
                  _ completionHandler: @escaping (StitchResult<Void>) -> Void)

    func deregister(_ completionHandler: @escaping (StitchResult<Void>) -> Void)
}
