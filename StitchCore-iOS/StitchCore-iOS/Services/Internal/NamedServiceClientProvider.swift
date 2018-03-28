import StitchCore

public protocol NamedServiceClientProvider {
    associatedtype T

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T
}

public struct AnyNamedServiceClientProvider<T> {
    private let clientBlock: (StitchService, StitchAppClientInfo) -> T

    fileprivate init<U: NamedServiceClientProvider>(provider: U) where U.T == T {
        self.clientBlock = provider.client
    }

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T {
        return self.clientBlock(service, client)
    }
}
