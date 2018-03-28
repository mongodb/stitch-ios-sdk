public protocol StitchAppClientConfiguration: StitchClientConfiguration {
    var clientAppId: String { get }
    var localAppName: String { get }
    var localAppVersion: String { get }
}

/** :nodoc: */
public struct StitchAppClientConfigurationImpl: StitchAppClientConfiguration, Buildee {
    public typealias TBuilder = StitchAppClientConfigurationBuilder

    public let baseURL: String
    public let storage: Storage
    public let transport: Transport
    public let clientAppId: String
    public let localAppName: String
    public let localAppVersion: String

    public init(_ builder: TBuilder) throws {
        guard let clientAppId = builder.clientAppId else {
            throw StitchAppClientConfigurationError.missingClientAppId
        }

        self.clientAppId = clientAppId
        
        if let appName = builder.localAppName {
            self.localAppName = appName
        } else {
            self.localAppName = "unkown app name"
        }
        
        if let appVersion = builder.localAppVersion {
            self.localAppVersion = appVersion
        } else {
            self.localAppVersion = "unknown app version"
        }
        
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
public enum StitchAppClientConfigurationError: Error {
    case missingClientAppId
}

public struct StitchAppClientConfigurationBuilder: StitchClientConfigurationBuilder, Builder {
    public typealias TBuildee = StitchAppClientConfigurationImpl

    public var baseURL: String?

    public var storage: Storage?

    public var transport: Transport?

    public var clientAppId: String?
    public var localAppName: String?
    public var localAppVersion: String?

    public init(_ builder: (inout StitchAppClientConfigurationBuilder) -> Void) {
        builder(&self)
    }

    public func build() throws -> StitchAppClientConfigurationImpl {
        return try StitchAppClientConfigurationImpl.init(self)
    }
}
