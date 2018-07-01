import StitchCoreSDK

/**
 * A protocol to be inherited by classes that need to take action whenever a particular `StitchAppClient` performs an
 * authentication event. An instance of a `StitchAuthDelegate` must be registered with a `StitchAuth` for this to work
 * correctly.
 */
public protocol StitchAuthDelegate: class {
    /**
     * A method to be called whenever a `StitchAppClient` performs an authentication event.
     * Note, when this method is invoked by a `StitchAuth` for which this delegate is registered,
     * the invocation will be dispatched to a non-main dispatch queue, so be sure to dispatch any
     * UI operations back to the main `DispatchQueue`.
     *
     * - parameters:
     *     - fromAuth: The `StitchAuth` object that caused the authentication event.
     */
    func onAuthEvent(fromAuth: StitchAuth)
}
