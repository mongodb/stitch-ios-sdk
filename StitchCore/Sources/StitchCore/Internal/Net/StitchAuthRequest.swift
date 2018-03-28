import ExtendedJSON
import Foundation

public protocol StitchAuthRequestBuilder: StitchRequestBuilder {
    var useRefreshToken: Bool? { get set }
}

public struct StitchAuthRequestBuilderImpl: StitchAuthRequestBuilder {
    public typealias TBuildee = StitchAuthRequestImpl

    public var useRefreshToken: Bool?

    public var path: String?

    public var method: Method?

    public var url: String?

    public var headers: [String : String]?

    public var body: Data?
    public var shouldRefreshOnFailure: Bool?

    public init(_ builder: (inout StitchAuthRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    public func build() throws -> StitchAuthRequestImpl {
        return try StitchAuthRequestImpl.init(self)
    }
}

public protocol StitchAuthRequest: StitchRequest {
    var useRefreshToken: Bool { get }
}

public struct StitchAuthRequestImpl: StitchAuthRequest {
    public typealias TBuilder = StitchAuthRequestBuilderImpl

    public var path: String

    public var method: Method

    public var headers: [String : String]

    public var body: Data?

    public var startedAt: TimeInterval

    public let useRefreshToken: Bool
    public let shouldRefreshOnFailure: Bool

    public init(_ builder: TBuilder) throws {
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.useRefreshToken = builder.useRefreshToken ?? false
        self.path = path
        self.method = method
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.startedAt = Date().timeIntervalSince1970
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}

public enum StitchAuthDocRequestBuilderError: Error {
    case missingDocument
}

public protocol StitchAuthDocRequestBuilder: StitchAuthRequestBuilder {
    var document: Document? { get set }
}

public struct StitchAuthDocRequestBuilderImpl: StitchAuthDocRequestBuilder {
    public typealias TBuildee = StitchAuthDocRequest

    public var document: Document?

    public var useRefreshToken: Bool?

    public var path: String?

    public var method: Method?

    public var headers: [String : String]?

    public var body: Data?

    public var shouldRefreshOnFailure: Bool?

    public init(_ builder: (inout StitchAuthDocRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    public func build() throws -> StitchAuthDocRequest {
        return try StitchAuthDocRequest.init(self)
    }
}

public struct StitchAuthDocRequest: StitchAuthRequest {
    public var useRefreshToken: Bool

    public var path: String

    public var method: Method

    public var headers: [String : String]

    public var body: Data?

    public var startedAt: TimeInterval

    public let document: Document

    public let shouldRefreshOnFailure: Bool

    public init(_ builder: StitchAuthDocRequestBuilderImpl) throws {
        guard let document = builder.document else {
            throw StitchAuthDocRequestBuilderError.missingDocument
        }
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.useRefreshToken = builder.useRefreshToken ?? false
        self.path = path
        self.method = method
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.startedAt = Date().timeIntervalSince1970
        self.document = document
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}
