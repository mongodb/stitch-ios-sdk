import StitchCore

/**
 * A protocol describing a class that can provide clients for a particular named Stitch service.
 */
public protocol ThrowingServiceClientProvider {
    /**
     * The type that this `ServiceClientProvider` can provide.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `StitchService` and `StitchAppClientInfo` objects.
     */
    func client(forService service: StitchService,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> ClientType
}

/**
 * A generic wrapper for a `NamedServiceClientProvider`.
 */
public struct AnyThrowingServiceClientProvider<T> {
    /**
     * A property containing the function that provides the service client object.
     */
    private let clientBlock: (StitchService, StitchAppClientInfo) throws -> T

    /**
     * Initializes this `AnyNamedServiceClientFactory` with an arbitrary `NamedServiceClientProvider`.
     */
    public init<U: ThrowingServiceClientProvider>(provider: U) where U.ClientType == T {
        self.clientBlock = provider.client
    }

    /**
     * Produces a service client with the stored `clientBlock`.
     */
    func client(forService service: StitchService,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> T {
        return try self.clientBlock(service, clientInfo)
    }
}
