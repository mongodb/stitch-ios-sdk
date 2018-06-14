import Foundation

public protocol NamedPushClientFactory {
    /**
     * The type that this `NamedPushClientFactory` can produce.
     */
    associatedtype ClientType

    /**
     * Returns a client of type `ClientType`, with the provided `StitchPushClient` and `OperationDispatcher` objects.
     */
    func client(withPushClient pushClient: StitchPushClient,
                withDispatcher dispatcher: OperationDispatcher) -> ClientType
}

/**
 * A generic wrapper for a `NamedPushClientFactory`.
 */
public struct AnyNamedPushClientFactory<T> {
    /**
     * A property containing the function that produces the service client object.
     */
    private let clientBlock: (StitchPushClient, OperationDispatcher) -> T

    /**
     * Initializes this `AnyNamedPushClientFactory` with an arbitrary `NamedPushClientFactory`.
     */
    public init<U: NamedPushClientFactory>(factory: U) where U.ClientType == T {
        self.clientBlock = factory.client
    }

    /**
     * Produces a push client with the stored `clientBlock`.
     */
    func client(withPushClient pushClient: StitchPushClient,
                withDispatcher dispatcher: OperationDispatcher) -> T {
        return self.clientBlock(pushClient, dispatcher)
    }
}
