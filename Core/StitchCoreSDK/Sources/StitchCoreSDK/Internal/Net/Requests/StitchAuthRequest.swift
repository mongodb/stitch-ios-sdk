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
     * Specifies that the request should use the temporary access token.
     */
    @discardableResult
    public func withAccessToken() -> Self {
        self.useRefreshToken = false
        return self
    }
    
    /**
     * Specifies that the request should use the permanent refresh token.
     */
    @discardableResult
    public func withRefreshToken() -> Self {
        self.useRefreshToken = true
        return self
    }
    
    /**
     * Sets whether or not the request client carrying out the request to be built should attempt to refresh the access
     * token and retry the operation if there was an invalid sesion error.
     */
    @discardableResult
    public func with(shouldRefreshOnFailure: Bool) -> Self {
        self.shouldRefreshOnFailure = shouldRefreshOnFailure
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
     * Constructs a builder preset with this request's properties.
     */
    public override var builder: StitchAuthRequestBuilder {
        return StitchAuthRequestBuilder.init(request: self)
    }
    
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
    
    public static func ==(lhs: StitchAuthRequest, rhs: StitchAuthRequest) -> Bool {
        return lhs as StitchRequest == rhs as StitchRequest
            && lhs.useRefreshToken == rhs.useRefreshToken
            && lhs.shouldRefreshOnFailure == rhs.shouldRefreshOnFailure
    }
}
