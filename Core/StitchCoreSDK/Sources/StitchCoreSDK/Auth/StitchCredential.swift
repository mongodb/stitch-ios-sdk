import MongoSwift

/**
 * A `StitchCredential` can be used to log in.
 * 
 * There is an implementation for each available
 * [Authentication Provider](https://docs.mongodb.com/stitch/authentication/providers/).
 * These implementations can be generated using an `AuthProviderClientFactory`.
 *
 * To log in, pass a credential implementation for the provider you want to use
 * to `StitchAuth`'s `loginWithCredential` method.
 *
 * - SeeAlso:
 * `StitchAuth`
 */
public protocol StitchCredential {
    /**
     * The name of the associated
     * [Authentication Provider](https://docs.mongodb.com/stitch/authentication/providers/).
     */
    var providerName: String { get }

    /**
     * The type of the associated 
     * [Authentication Provider](https://docs.mongodb.com/stitch/authentication/providers/).
     */
    static var providerType: StitchProviderType { get }

    /**
     * The contents of this credential as they will be passed to the Stitch server.
     */
    var material: Document { get }

    /**
     * A `ProviderCapabilities` struct describing the behavior of this credential when logging in.
     */
    var providerCapabilities: ProviderCapabilities { get }
}
