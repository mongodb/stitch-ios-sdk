import Foundation

/**
 * StitchPush can be used to get clients that can register for push notifications via Stitch.
 */
public protocol StitchPush {
    /**
     * Gets a push client for the given named push service.
     *
     * - parameters:
     *     - factory: the factory that will create a client for the push service
     *     - serviceName: the name of the push service
     * - returns: A client to interact with the push service
     */
    func client<T>(forFactory factory: AnyNamedPushClientFactory<T>, withName serviceName: String) -> T
}
