import Foundation

/**
 * An error that the request builder can throw if it is missing certain configuration properties.
 */
public enum RequestBuilderError: Error {
    case missingMethod
    case missingURL
    case missingTimeout
}

/**
 * A builder that can build a `Request` object.
 */
public class RequestBuilder {
    internal var method: Method?
    internal var url: String?
    internal var timeout: TimeInterval?
    internal var headers: [String: String]?
    internal var body: Data?

    /**
     * Sets the HTTP method of the request to be built.
     */
    @discardableResult
    public func with(method: Method) -> Self {
        self.method = method
        return self
    }
    
    /**
     * Sets the URL of the request to be built.
     */
    @discardableResult
    public func with(url: String) -> Self {
        self.url = url
        return self
    }

    /**
     * Sets the number of seconds that the underlying transport should spend on an HTTP round trip before failing with
     * an error.
     */
    @discardableResult
    public func with(timeout: TimeInterval) -> Self {
        self.timeout = timeout
        return self
    }

    /**
     * Sets the HTTP headers of the request to be built.
     */
    @discardableResult
    public func with(headers: [String: String]) -> Self {
        self.headers = headers
        return self
    }

    /**
     * Sets the body of the request to be built.
     */
    @discardableResult
    public func with(body: Data?) -> Self {
        self.body = body
        return self
    }
    
    public init() { }
    
    init(request: Request) {
        self.method = request.method
        self.url = request.url
        self.timeout = request.timeout
        self.headers = request.headers
        self.body = request.body
    }

    /**
     * Builds the `Request`.
     * - throws: `RequestBuilderError` if the builder is missing an HTTP method, a URL, or a timeout.
     */
    public func build() throws -> Request {
        guard let method = self.method else {
            throw RequestBuilderError.missingMethod
        }
        guard let url = self.url else {
            throw RequestBuilderError.missingURL
        }
        guard let timeout = self.timeout else {
            throw RequestBuilderError.missingTimeout
        }
        
        return Request.init(
            method: method,
            url: url,
            timeout: timeout,
            headers: self.headers ?? [:],
            body: self.body
        )
    }
}

/**
 * An HTTP request that can be made to an arbitrary server.
 */
public class Request: Equatable {

    // MARK: Properties
    
    public var builder: RequestBuilder {
        return RequestBuilder.init(request: self)
    }

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

    // MARK: Initializers
    
    internal init(request: Request) {
        self.method = request.method
        self.url = request.url
        self.timeout = request.timeout
        self.headers = request.headers
        self.body = request.body
    }
    
    internal init(method: Method,
                  url: String,
                  timeout: TimeInterval,
                  headers: [String: String],
                  body: Data?) {
        self.method = method
        self.url = url
        self.timeout = timeout
        self.headers = headers
        self.body = body
    }

    public static func ==(lhs: Request, rhs: Request) -> Bool {
        let bodiesEqual =
            (lhs.body == nil && rhs.body == nil) || (lhs.body ?? Data()).elementsEqual(rhs.body ?? Data())
        return lhs.method == rhs.method && lhs.headers == rhs.headers && bodiesEqual && lhs.url == rhs.url
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
    
    /**
     * Initializes the response and preprocesses the headers to support non-canonical headers.
     */
    public init(statusCode: Int,
                headers: [String: String],
                body: Data?) {
        self.statusCode = statusCode
        self.body = body
        
        var processedHeaders: [String: String] = [:]
        headers.forEach { (key, val) in
            processedHeaders[key.lowercased(with: Locale.init(identifier: "en_US"))] = val
        }
        self.headers = processedHeaders
    }
}
