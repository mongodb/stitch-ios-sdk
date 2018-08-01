import StitchCoreSDK

/**
 * A protocol describing a class that can provide clients for a particular named Stitch service.
 */
public protocol ThrowingServiceClientFactory {
    /**
     * The type that this `ThrowingServiceClientFactory` can provide.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `CoreStitchServiceClient` and `StitchAppClientInfo`
     * objects.
     */
    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> ClientType
}

/**
 * A generic wrapper for a `ThrowingServiceClientFactory`.
 */
public struct AnyThrowingServiceClientFactory<T> {
    /**
     * A property containing the function that provides the service client object.
     */
    private let clientBlock: (CoreStitchServiceClient, StitchAppClientInfo) throws -> T

    /**
     * Initializes this `AnyThrowingServiceClientFactory` with an arbitrary `ThrowingServiceClientFactory`.
     */
    public init<U: ThrowingServiceClientFactory>(factory: U) where U.ClientType == T {
        self.clientBlock = factory.client
    }

    /**
     * Produces a service client with the stored `clientBlock`.
     */
    func client(forService service: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> T {
        return try self.clientBlock(service, clientInfo)
    }
}
