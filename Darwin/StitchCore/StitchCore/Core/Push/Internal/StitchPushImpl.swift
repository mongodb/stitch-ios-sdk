import Foundation
import StitchCoreSDK

public class StitchPushImpl: StitchPush {
    private let requestClient: StitchAuthRequestClient
    private let pushRoutes: StitchPushRoutes
    private let dispatcher: OperationDispatcher

    public init(requestClient: StitchAuthRequestClient,
                pushRoutes: StitchPushRoutes,
                dispatcher: OperationDispatcher) {
        self.requestClient = requestClient
        self.pushRoutes = pushRoutes
        self.dispatcher = dispatcher
    }

    public func client<T>(fromFactory factory: AnyNamedPushClientFactory<T>, withName serviceName: String) -> T {
        return factory.client(
            withPushClient: StitchPushClientImpl.init(
                requestClient: self.requestClient,
                routes: self.pushRoutes,
                name: serviceName,
                dispatcher: self.dispatcher),
            withDispatcher: self.dispatcher)
    }
}
