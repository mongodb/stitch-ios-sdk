import StitchCore

public protocol NamedServiceClientProvider {
    associatedtype ClientType

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> ClientType
}

public struct AnyNamedServiceClientProvider<T> {
    private let clientBlock: (StitchService, StitchAppClientInfo) -> T

    fileprivate init<U: NamedServiceClientProvider>(provider: U) where U.ClientType == T {
        self.clientBlock = provider.client
    }

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> T {
        return self.clientBlock(service, client)
    }
}
