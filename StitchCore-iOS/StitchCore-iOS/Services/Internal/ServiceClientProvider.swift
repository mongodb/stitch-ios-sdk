import StitchCore

public protocol ServiceClientProvider {
    associatedtype T

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T
}

public struct AnyServiceClientProvider<T> {
    private let clientBlock: (StitchService, StitchAppClientInfo) -> T

    fileprivate init<U: ServiceClientProvider>(provider: U) where U.T == T {
        self.clientBlock = provider.client
    }

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T {
        return self.clientBlock(service, client)
    }
}
