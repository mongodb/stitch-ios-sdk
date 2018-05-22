import Foundation

/**
 * An error that the request builder can throw if it is missing certain configuration properties.
 */
public enum RequestBuilderError: Error {
    case missingMethod
    case missingUrl
    case missingTimeout
}

/**
 * A builder that can build a `Request` object.
 */
public struct RequestBuilder: Builder {
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = Request

    /**
     * The HTTP method of the request to be built.
     */
    public var method: Method?

    /**
     * The URL of the request to be built.
     */
    public var url: String?

    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error.
     */
    public var timeout: TimeInterval?

    /**
     * The HTTP headers of the request to be built.
     */
    public var headers: [String: String]?

    /**
     * The body of the rqeuest to be built.
     */
    public var body: Data?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout RequestBuilder) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `Request`.
     */
    public func build() throws -> Request {
        return try Request.init(self)
    }
}

/**
 * An HTTP request that can be made to an arbitrary server.
 */
public struct Request: Buildee {
    /**
     * The type that builds this request object.
     */
    public typealias TBuilder = RequestBuilder

    // MARK: Properties

    /**
     * The HTTP method of this request.
     */
    public var method: Method

    /**
     * The URL to which this request will be made.
     */
    public var url: String

    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error.
     */
    public var timeout: TimeInterval

    /**
     * The HTTP headers of this request.
     */
    public var headers: [String: String]

    /**
     * The body of the request.
     */
    public var body: Data?

    // MARK: Initializer

    /**
     * Initializes this request by accepting a `RequestBuilder`.
     *
     * - throws: `RequestBuilderError` if the builder is missing an HTTP method, a URL, or a timeout.
     */
    public init(_ builder: RequestBuilder) throws {
        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }
        guard let url = builder.url else {
            throw RequestBuilderError.missingUrl
        }
        guard let timeout = builder.timeout else {
            throw RequestBuilderError.missingTimeout
        }

        self.method = method
        self.url = url
        self.timeout = timeout

        self.headers = builder.headers ?? [:]
        self.body = builder.body
    }
}

/**
 * The contents of an HTTP response.
 */
public struct Response {
    /**
     * The status code of the HTTP response.
     */
    public let statusCode: Int

    /**
     * The headers of the HTTP response.
     */
    public let headers: [String: String]

    /**
     * The body of the HTTP response.
     */
    public let body: Data?
}
