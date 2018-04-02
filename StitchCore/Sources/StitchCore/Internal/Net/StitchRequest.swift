import Foundation
import ExtendedJSON

public enum StitchRequestBuilderError: Error {
    case missingPath
}

public protocol StitchRequestBuilder: Builder {
    var method: Method? { get set }
    var headers: [String: String]? { get set }
    var body: Data? { get set }
    var path: String? { get set }
}

public struct StitchRequestBuilderImpl: StitchRequestBuilder {
    public typealias TBuildee = StitchRequestImpl

    public var method: Method?
    public var body: Data?
    public var headers: [String: String]?
    public var path: String?
    public var shouldRefreshOnFailure: Bool?

    public init(_ builder: (inout StitchRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    public func build() throws -> StitchRequestImpl {
        return try StitchRequestImpl.init(self)
    }
}

public protocol StitchRequest: Buildee {
    var path: String { get }
    var method: Method { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var shouldRefreshOnFailure: Bool { get }
    var startedAt: TimeInterval { get }
}

public struct StitchRequestImpl: StitchRequest {
    public typealias TBuilder = StitchRequestBuilderImpl

    public let path: String
    public let method: Method
    public let headers: [String: String]
    public let body: Data?

    public let startedAt: TimeInterval
    public let shouldRefreshOnFailure: Bool

    public init(_ builder: TBuilder) throws {
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.path = path
        self.method = method
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.startedAt = Date().timeIntervalSince1970
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}

public protocol StitchDocRequestBuilder: StitchRequestBuilder {
    var document: Document? { get set }
}

public struct StitchDocRequestBuilderImpl: StitchDocRequestBuilder {
    public typealias TBuildee = StitchDocRequest

    public var document: Document?
    public var path: String?
    public var method: Method?
    public var url: String?
    public var headers: [String: String]?
    public var body: Data?
    public var shouldRefreshOnFailure: Bool?

    public init(_ builder: (inout StitchDocRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    public func build() throws -> StitchDocRequest {
        return try StitchDocRequest.init(self)
    }
}

public struct StitchDocRequest: StitchRequest {
    public var path: String

    public var method: Method

    public var headers: [String: String]

    public var body: Data?

    public var startedAt: TimeInterval

    public let document: Document
    public let shouldRefreshOnFailure: Bool

    public init(_ builder: StitchDocRequestBuilderImpl) throws {
        guard let document = builder.document else {
            throw StitchAuthDocRequestBuilderError.missingDocument
        }
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.path = path
        self.method = method
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.document = document
        self.startedAt = Date().timeIntervalSince1970
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}
