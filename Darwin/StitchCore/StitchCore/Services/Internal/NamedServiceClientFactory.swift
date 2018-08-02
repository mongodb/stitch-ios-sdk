import StitchCoreSDK

/**
 * A protocol describing a class that can provide clients for a particular named Stitch service.
 */
public protocol NamedServiceClientFactory {
    /**
     * The type that this `NamedServiceClientFactory` can produce.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `CoreStitchServiceClient` and `StitchAppClientInfo`
     * objects.
     */
    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> ClientType
}

/**
 * A generic wrapper for a `NamedServiceClientFactory`.
 */
public struct AnyNamedServiceClientFactory<T> {
    /**
     * A property containing the function that produces the service client object.
     */
    private let clientBlock: (CoreStitchServiceClient, StitchAppClientInfo) -> T

    /**
     * Initializes this `AnyNamedServiceClientFactory` with an arbitrary `NamedServiceClientFactory`.
     */
    public init<U: NamedServiceClientFactory>(factory: U) where U.ClientType == T {
        self.clientBlock = factory.client
    }

    /**
     * Produces a service client with the stored `clientBlock`.
     */
    func client(forService service: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> T {
        return self.clientBlock(service, clientInfo)
    }
}
