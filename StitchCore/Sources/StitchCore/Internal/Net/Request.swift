import Foundation

public enum RequestBuilderError: Error {
    case missingMethod
    case missingUrl
}

public struct RequestBuilder: Builder {
    public typealias TBuildee = Request

    public var method: Method?
    public var url: String?
    public var headers: [String: String]?
    public var body: Data?

    public init(_ builder: (inout RequestBuilder) -> Void) {
        builder(&self)
    }

    public func build() throws -> Request {
        return try Request.init(self)
    }
}

public struct Request: Buildee {
    public typealias TBuilder = RequestBuilder

    public var method: Method
    public var url: String
    public var headers: [String: String]
    public var body: Data?

    public init(_ builder: RequestBuilder) throws {
        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }
        guard let url = builder.url else {
            throw RequestBuilderError.missingUrl
        }

        self.method = method
        self.url = url

        self.headers = builder.headers ?? [:]
        self.body = builder.body
    }
}

public struct Response {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data?
}
