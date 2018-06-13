import MongoSwift

/**
 * A credential which can be used to log in as a Stitch user. There is an implementation for each authentication
 * provider available in MongoDB Stitch. These implementations can be generated using an authentication provider
 * client.
 */
public protocol StitchCredential {
    /**
     * The name of the authentication provider that this credential will be used to authenticate with.
     */
    var providerName: String { get }

    /**
     * The type of the authentication provider that this credential will be used to authenticate with.
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
