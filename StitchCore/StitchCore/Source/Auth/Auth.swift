import Foundation

/// Auth represents the current authorization state of the client
public struct Auth {
    
    private static let accessTokenKey =         "accessToken"
    private static let userIdKey =              "userId"
    private static let deviceId =               "deviceId"
    
    /**
         The current access token for this session.
     */
    let accessToken: String
    
    /**
     *   The current access token for this session in decoded JWT form.
     *   Will be nil if the token was malformed and could not be decoded.
     */
    let accessTokenJwt: DecodedJWT?
    
    /**
         The user this session was created for.
     */
    let deviceId: String
    
    /**
         The user this session was created for.
     */
    public let userId: String?
    
    var json: [String : Any] {
        return [Auth.accessTokenKey : accessToken,
                // TODO: remove once userId is guarenteed to be in the call (backend task)
                Auth.userIdKey : userId ?? "",
                Auth.deviceId : deviceId]
    }
    
    
    //MARK: - Init
    private init(accessToken: String, userId: String?, deviceId: String) {
        self.accessToken = accessToken
        self.accessTokenJwt = try? DecodedJWT(jwt: self.accessToken)
        self.userId = userId
        self.deviceId = deviceId
    }
    
    /**
     - parameter dictionary: Dict containing the access token, userId, and deviceId necessary to create
         this auth object
     */
    internal init(dictionary: [String : Any]) throws {
        
        guard let accessToken = dictionary[Auth.accessTokenKey] as? String,
            let userId = dictionary[Auth.userIdKey] as? String?,
            let deviceId = dictionary[Auth.deviceId] as? String else {
                throw StitchError.responseParsingFailed(reason: "failed creating Auth out of info: \(dictionary)")
        }
        
        self = Auth(accessToken: accessToken, userId: userId, deviceId: deviceId)
    }
    
    internal func auth(with updatedAccessToken: String) -> Auth {
        return Auth(accessToken: updatedAccessToken, userId: userId, deviceId: deviceId)
    }
    
    /**
         Determines if the access token stored in this Auth object is expired or expiring within
         a provided number of seconds.
     
     - parameter withinSeconds: expiration threshold in seconds. 10 by default to account for latency and clock drift
                                between client and Stitch server
     - returns: true if the access token is expired or is going to expire within 'withinSeconds' seconds
                false if the access token exists and is not expired nor expiring within 'withinSeconds' seconds
                nil if the access token doesn't exist, is malformed, or does not have an 'exp' field.
     */
    public func isAccessTokenExpired(withinSeconds: Double = 10.0) -> Bool? {
        if let exp = self.accessTokenJwt?.expiration {
            return Date() >= (exp - TimeInterval(withinSeconds))
        }
        return nil
    }
}
