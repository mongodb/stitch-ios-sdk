import Foundation

/**
 * StitchPush can be used to get clients that can register for push notifications via Stitch.
 */
public protocol StitchPush {
    /**
     * Gets a push client for the push service associated with the specified name and factory.
     *
     * - parameters:
     *     - fromFactory: The factory that will create a client for the push service. Each service that offers the
     *                    capability of registering for push notifications will offer a static factory.
     *     - serviceName: the name of the push service
     * - returns: A client to interact with the push service.
     */
    func client<T>(fromFactory factory: AnyNamedPushClientFactory<T>, withName serviceName: String) -> T
}
