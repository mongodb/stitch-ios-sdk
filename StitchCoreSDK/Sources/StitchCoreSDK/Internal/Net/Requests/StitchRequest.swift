import Foundation

/**
 * A builder that can build a `StitchRequest` object.
 */
public class StitchRequestBuilder {
    internal var method: Method?
    internal var body: Data?
    internal var headers: [String: String]?
    internal var timeout: TimeInterval?
    internal var path: String?
    
    /**
     * Sets the HTTP method of the request to be built.
     */
    @discardableResult
    public func with(method: Method) -> Self {
        self.method = method
        return self
    }
    
    /**
     * Sets the body of the request to be built.
     */
    @discardableResult
    public func with(body: Data) -> Self {
        self.body = body
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
     * Sets the number of seconds that the underlying transport should spend on an HTTP round trip before failing with
     * an error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    @discardableResult
    public func with(timeout: TimeInterval) -> Self {
        self.timeout = timeout
        return self
    }
    
    /**
     * Sets the URL of the request to be built.
     */
    @discardableResult
    public func with(path: String) -> Self {
        self.path = path
        return self
    }
    
    public init() { }
    
    init(request: StitchRequest) {
        self.method = request.method
        self.body = request.body
        self.headers = request.headers
        self.timeout = request.timeout
        self.path = request.path
    }

    /**
     * Builds the `StitchRequest`.
     */
    public func build() throws -> StitchRequest {
        guard let path = self.path else {
            throw RequestBuilderError.missingURL
        }
        
        guard let method = self.method else {
            throw RequestBuilderError.missingMethod
        }
        
        return StitchRequest.init(
            path: path,
            method: method,
            headers: self.headers ?? [:],
            timeout: self.timeout,
            body: self.body
        )
    }
}

/**
 * A class representing an HTTP request that can be made to a Stitch server.
 */
public class StitchRequest: Equatable {
    
    /**
     * Constructs a builder preset with this request's properties.
     */
    public var builder: StitchRequestBuilder {
        return StitchRequestBuilder.init(request: self)
    }
    
    /**
     * The URL to which this request will be made.
     */
    public let path: String
    
    /**
     * The HTTP method of this request.
     */
    public let method: Method
    
    /**
     * The HTTP headers of this request.
     */
    public let headers: [String: String]
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error.  If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public let timeout: TimeInterval?
    
    /**
     * The body of the request.
     */
    public let body: Data?
    
    /**
     * A `TimeInterval` indicating the time that the request was made (since the Unix epoch).
     */
    public let startedAt: TimeInterval
    
    internal init(request: StitchRequest) {
        self.path = request.path
        self.method = request.method
        self.headers = request.headers
        self.timeout = request.timeout
        self.body = request.body
        self.startedAt = request.startedAt
    }
    
    internal init(path: String,
                  method: Method,
                  headers: [String: String],
                  timeout: TimeInterval?,
                  body: Data?) {
        self.path = path
        self.method = method
        self.headers = headers
        self.timeout = timeout
        self.body = body
        self.startedAt = Date().timeIntervalSince1970
    }
    
    public static func ==(lhs: StitchRequest, rhs: StitchRequest) -> Bool {
        let bodiesEqual =
            (lhs.body == nil && rhs.body == nil) || (lhs.body ?? Data()).elementsEqual(rhs.body ?? Data())
        return lhs.method == rhs.method && lhs.headers == rhs.headers && bodiesEqual && lhs.path == rhs.path
    }
}
