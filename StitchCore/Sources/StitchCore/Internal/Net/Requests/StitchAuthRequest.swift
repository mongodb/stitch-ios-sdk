import Foundation

/**
 * A builder that can build a `StitchAuthRequest` object.
 */
public class StitchAuthRequestBuilder: StitchRequestBuilder {
    internal var useRefreshToken: Bool = false
    internal var shouldRefreshOnFailure: Bool = true
    
    public override init() { super.init() }
    
    init(request: StitchAuthRequest) {
        super.init(request: request)
        self.useRefreshToken = request.useRefreshToken
        self.shouldRefreshOnFailure = request.shouldRefreshOnFailure
    }
    
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchAuthRequest
    
    /**
     * Specifies that the request should use the temporary access token.
     */
    @discardableResult
    public func withAccessToken() -> StitchAuthRequestBuilder {
        self.useRefreshToken = false
        return self
    }
    
    /**
     * Specifies that the request should use the permanent refresh token.
     */
    @discardableResult
    public func withRefreshToken() -> StitchAuthRequestBuilder {
        self.useRefreshToken = true
        return self
    }
    
    /**
     * Sets whether or not the request client carrying out the request to be built should attempt to refresh the access
     * token and retry the operation if there was an invalid sesion error.
     */
    @discardableResult
    public func with(shouldRefreshOnFailure: Bool) -> StitchAuthRequestBuilder {
        self.shouldRefreshOnFailure = shouldRefreshOnFailure
        return self
    }
    
    /**
     * Sets the HTTP method of the request to be built.
     */
    @discardableResult
    public override func with(method: Method) -> StitchAuthRequestBuilder {
        self.method = method
        return self
    }
    
    /**
     * Sets the body of the request to be built.
     */
    @discardableResult
    public override func with(body: Data) -> StitchAuthRequestBuilder {
        self.body = body
        return self
    }
    
    /**
     * Sets the HTTP headers of the request to be built.
     */
    @discardableResult
    public override func with(headers: [String: String]) -> StitchAuthRequestBuilder {
        self.headers = headers
        return self
    }
    
    /**
     * Sets the number of seconds that the underlying transport should spend on an HTTP round trip before failing with
     * an error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    @discardableResult
    public override func with(timeout: TimeInterval) -> StitchAuthRequestBuilder {
        self.timeout = timeout
        return self
    }
    
    /**
     * Sets the URL of the request to be built.
     */
    @discardableResult
    public override func with(path: String) -> StitchAuthRequestBuilder {
        self.path = path
        return self
    }

    /**
     * Builds the `StitchAuthRequest` as a `StitchAuthRequestImpl`.
     */
    public override func build() throws -> StitchAuthRequest {
        if self.useRefreshToken {
            self.shouldRefreshOnFailure = false
        }
        return try StitchAuthRequest.init(
            stitchRequest: super.build(),
            useRefreshToken: self.useRefreshToken,
            shouldRefreshOnFailure: self.shouldRefreshOnFailure
        )
    }
}

/**
 * A class representing an authenticated HTTP request that can be made to a Stitch server.
 */
public class StitchAuthRequest: StitchRequest {
    /**
     * Whether or not the request should use the refresh token instead of the temporary access token.
     */
    public let useRefreshToken: Bool

    /**
     * Whether or not the request client carrying out this request should attempt to refresh the access token and retry
     * the operation if there was an invalid sesion error.
     */
    public let shouldRefreshOnFailure: Bool
    
    /**
     * Constructs a request from an existing authenticated request.
     */
    internal init(stitchAuthRequest: StitchAuthRequest) {
        self.useRefreshToken = stitchAuthRequest.useRefreshToken
        self.shouldRefreshOnFailure = stitchAuthRequest.shouldRefreshOnFailure
        super.init(request: stitchAuthRequest)
    }
    
    /**
     * Upgrades a request to an authenticated request.
     */
    internal init(stitchRequest: StitchRequest, useRefreshToken: Bool) {
        self.useRefreshToken = useRefreshToken
        self.shouldRefreshOnFailure = !useRefreshToken
        super.init(request: stitchRequest)
    }
    
    fileprivate init(stitchRequest: StitchRequest,
                     useRefreshToken: Bool,
                     shouldRefreshOnFailure: Bool) {
        self.useRefreshToken = useRefreshToken
        self.shouldRefreshOnFailure = shouldRefreshOnFailure
        super.init(request: stitchRequest)
    }
}
