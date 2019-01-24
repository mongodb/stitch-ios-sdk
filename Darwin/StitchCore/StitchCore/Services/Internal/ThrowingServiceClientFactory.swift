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

/**
 * A protocol describing a class that can provide clients for a particular named Stitch service.
 */
public protocol NamedThrowingServiceClientFactory {
    /**
     * The type that this `NamedThrowingServiceClientFactory` can produce.
     */
    associatedtype ClientType

    // swiftlint:disable line_length

    /**
     * Returns a client of type `ClientType`, with the provided `CoreStitchServiceClient` and `StitchAppClientInfo`
     * objects.
     */
    func client(withServiceClient serviceClient: CoreStitchServiceClient, withClientInfo clientInfo: StitchAppClientInfo) throws -> ClientType

    // swiftlint:enable line_length
}

/**
 * A generic wrapper for a `NamedThrowingServiceClientFactory`.
 */
public struct AnyNamedThrowingServiceClientFactory<T> {
    /**
     * A property containing the function that produces the service client object.
     */
    private let clientBlock: (CoreStitchServiceClient, StitchAppClientInfo) throws -> T

    /**
     * Initializes this `AnyNamedThrowingServiceClientFactory` with an arbitrary `NamedThrowingServiceClientFactory`.
     */
    public init<U: NamedThrowingServiceClientFactory>(factory: U) where U.ClientType == T {
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
