import StitchCoreSDK

/**
 * A protocol describing a class that can provide clients for a particular Stitch service.
 */
public protocol ServiceClientFactory {
    /**
     * The type that this `ServiceClientFactory` can provide.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `StitchServiceClient` and `StitchAppClientInfo` objects.
     */
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> ClientType
}

/**
 * A generic wrapper for a `ServiceClientFactory`.
 */
public struct AnyServiceClientFactory<T> {
    /**
     * A property containing the function that provides the service client object.
     */
    private let clientBlock: (StitchServiceClient, StitchAppClientInfo) -> T

    /**
     * Initializes this `AnyServiceClientFactory` with an arbitrary `ServiceClientFactory`.
     */
    public init<U: ServiceClientFactory>(factory: U) where U.ClientType == T {
        self.clientBlock = factory.client
    }

    /**
     * Produces a service client with the stored `clientBlock`.
     */
    func client(forService service: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> T {
        return self.clientBlock(service, clientInfo)
    }
}
