public protocol StitchClientConfiguration {
    var baseURL: String { get }
    var storage: Storage { get }
    var transport: Transport { get }
}

/** :nodoc: */
public struct StitchClientConfigurationImpl: StitchClientConfiguration, Buildee {
    public typealias TBuilder = StitchClientConfigurationBuilderImpl

    public let baseURL: String
    public let storage: Storage
    public let transport: Transport

    public init(_ builder: TBuilder) throws {
        guard let baseURL = builder.baseURL else {
            throw StitchClientConfigurationError.missingBaseURL
        }

        guard let storage = builder.storage else {
            throw StitchClientConfigurationError.missingStorage
        }

        guard let transport = builder.transport else {
            throw StitchClientConfigurationError.missingTransport
        }

        self.baseURL = baseURL
        self.storage = storage
        self.transport = transport
    }
}

/** :nodoc: */
public enum StitchClientConfigurationError: Error {
    case missingBaseURL
    case missingStorage
    case missingTransport
}

/** :nodoc: */
public protocol StitchClientConfigurationBuilder {
    var baseURL: String? { get }
    var storage: Storage? { get }
    var transport: Transport? { get }
}

/** :nodoc: */
public protocol Buildee {
    associatedtype TBuilder: Builder
    init(_ builder: TBuilder) throws
}

/** :nodoc: */
public protocol Builder {
    associatedtype TBuildee: Buildee

    init(_ builder: (inout Self) -> Void)
    func build() throws -> TBuildee
}

/** :nodoc: */
public struct StitchClientConfigurationBuilderImpl: StitchClientConfigurationBuilder, Builder {
    public var baseURL: String?
    public var storage: Storage?
    public var transport: Transport?

    public typealias TBuildee = StitchClientConfigurationImpl

    public init(_ builder: (inout StitchClientConfigurationBuilderImpl) -> Void) {
        builder(&self)
    }
    
    public func build() throws -> TBuildee {
        return try StitchClientConfigurationImpl.init(self)
    }
}



