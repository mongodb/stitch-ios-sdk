import Foundation

/**
 * An error that the HttpRequest builder can throw if it is missing certain configuration properties.
 */
public enum HttpRequestBuilderError: Error {
    case missingMethod
    case missingUrl
}

/**
 * An HttpRequest encapsulates the details of an HTTP request over the HTTP service.
 */
public struct HttpRequest {
    /**
     * The URL that the request will be performed against.
     */
    public let url: String
    
    /**
     * The HTTP method of the request.
     */
    public let method: HttpMethod
    
    /**
     * The URL that will be used to capture cookies for authentication before the actual request is executed.
     */
    public let authUrl: String?
    
    /**
     * The headers that will be included in the request.
     */
    public let headers: [String: [String]]?
    
    /**
     * The cookies that will be included in the request.
     */
    public let cookies: [String: String]?
    
    /**
     * The body that will be included in the request.
     */
    public let body: Data?
    
    /**
     * Whether or not the included body should be encoded as extended JSON when sent to the url in this request.
     */
    public let encodeBodyAsJson: Bool?
    
    /**
     * The form that will be included in the request.
     */
    public let form: [String: String]?
    
    /**
     * Whether or not Stitch should follow redirects while executing the request. Defaults to false.
     */
    public let followRedirects: Bool?
}

public class HttpRequestBuilder {
    internal var url: String?
    internal var method: HttpMethod?
    internal var authUrl: String?
    internal var headers: [String: [String]]?
    internal var cookies: [String: String]?
    internal var body: Data?
    internal var encodeBodyAsJson: Bool?
    internal var form: [String: String]?
    internal var followRedirects: Bool?
    
    public init() { }
    
    /**
     * Sets the URL that the request will be performed against.
     */
    @discardableResult
    public func with(url: String) -> Self {
        self.url = url
        return self
    }
    
    /**
     * Sets the HTTP method of the request.
     */
    @discardableResult
    public func with(method: HttpMethod) -> Self {
        self.method = method
        return self
    }
    
    /**
     * Sets the URL that will be used to capture cookies for authentication before the actual request is executed.
     */
    @discardableResult
    public func with(authUrl: String) -> Self {
        self.authUrl = authUrl
        return self
    }
    
    /**
     * Sets the headers that will be included in the request.
     */
    @discardableResult
    public func with(headers: [String: [String]]) -> Self {
        self.headers = headers
        return self
    }
    
    /**
     * Sets the cookies that will be included in the request.
     */
    @discardableResult
    public func with(cookies: [String: String]) -> Self {
        self.cookies = cookies
        return self
    }
    
    /**
     * Sets the body that will be included in the request.
     */
    @discardableResult
    public func with(body: Data?) -> Self {
        self.body = body
        return self
    }
    
    /**
     * Sets whether or not the included body should be encoded as extended JSON when sent to the url in this request.
     * Defaults to false if not set.
     */
    @discardableResult
    public func with(encodeBodyAsJson: Bool) -> Self {
        self.encodeBodyAsJson = encodeBodyAsJson
        return self
    }
    
    /**
     * Sets the form that will be included in the request.
     */
    @discardableResult
    public func with(form: [String: String]) -> Self {
        self.form = form
        return self
    }
    
    /**
     * Sets whether or not Stitch should follow redirects while executing the request. Defaults to false if not set.
     */
    @discardableResult
    public func with(followRedirects: Bool) -> Self {
        self.followRedirects = followRedirects
        return self
    }
    
    /**
     * Builds, validates, and returns the `HttpRequest`.
     */
    public func build() throws -> HttpRequest {
        guard let url = url, url != "" else {
            throw HttpRequestBuilderError.missingUrl
        }
        
        guard let method = method else {
            throw HttpRequestBuilderError.missingMethod
        }
        
        return HttpRequest.init(
            url: url,
            method: method,
            authUrl: authUrl,
            headers: headers,
            cookies: cookies,
            body: body,
            encodeBodyAsJson: encodeBodyAsJson,
            form: form,
            followRedirects: followRedirects
        )
    }
}

