import Foundation
import MongoSwift

/**
 * StitchPushClient is used to register for push notifications.
 */
public protocol StitchPushClient {
    func register(withRegistrationInfo registrationInfo: Document,
                  _ completionHandler: @escaping (StitchResult<Void>) -> Void)

    func deregister(_ completionHandler: @escaping (StitchResult<Void>) -> Void)
}
