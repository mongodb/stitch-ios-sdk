import StitchCore

/**
 * A protocol describing a class that can provide clients for a particular Stitch service.
 */
public protocol ServiceClientProvider {
    /**
     * The type that this `ServiceClientProvider` can provide.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `StitchService` and `StitchAppClientInfo` objects.
     */
    func client(forService service: StitchService, withClient client: StitchAppClientInfo) -> ClientType
}

/**
 * A generic wrapper for a `ServiceClientProvider`.
 */
public struct AnyServiceClientProvider<T> {
    /**
     * A property containing the function that provides the service client object.
     */
    private let clientBlock: (StitchService, StitchAppClientInfo) -> T

    /**
     * Initializes this `AnyServiceClientProvider` with an arbitrary `ServiceClientProvider`.
     */
    fileprivate init<U: ServiceClientProvider>(provider: U) where U.ClientType == T {
        self.clientBlock = provider.client
    }

    /**
     * Produces a service client with the stored `clientBlock`.
     */
    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T {
        return self.clientBlock(service, client)
    }
}
