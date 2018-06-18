import Foundation

public protocol CoreStitchPushClient {
    func registerInternal(withRegistrationInfo registrationInfo: Document) throws
    
    func deregisterInternal() throws
}
