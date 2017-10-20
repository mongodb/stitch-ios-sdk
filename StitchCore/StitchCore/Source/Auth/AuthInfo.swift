import Foundation

/// Auth represents the current authorization state of the client
public struct AuthInfo {

    private static let accessTokenKey =         "accessToken"
    private static let userIdKey =              "userId"
    private static let deviceId =               "deviceId"

    /**
         The current access token for this session.
     */
    let accessToken: String
    /**
         The user this session was created for.
     */
    let deviceId: String

    /**
         The user this session was created for.
     */
    public let userId: String?

    var json: [String: Any] {
        return [AuthInfo.accessTokenKey: accessToken,
                // TODO: remove once userId is guarenteed to be in the call (backend task)
                AuthInfo.userIdKey: userId ?? "",
                AuthInfo.deviceId: deviceId]
    }

    // MARK: - Init
    private init(accessToken: String, userId: String?, deviceId: String) {
        self.accessToken = accessToken
        self.userId = userId
        self.deviceId = deviceId
    }

    /**
     - parameter dictionary: Dict containing the access token, userId, and deviceId necessary to create
         this auth object
     */
    internal init(dictionary: [String: Any]) throws {

        guard let accessToken = dictionary[AuthInfo.accessTokenKey] as? String,
            let userId = dictionary[AuthInfo.userIdKey] as? String?,
            let deviceId = dictionary[AuthInfo.deviceId] as? String else {
                throw StitchError.responseParsingFailed(reason: "failed creating Auth out of info: \(dictionary)")
        }

        self = AuthInfo(accessToken: accessToken, userId: userId, deviceId: deviceId)
    }

    internal func auth(with updatedAccessToken: String) -> AuthInfo {
        return AuthInfo(accessToken: updatedAccessToken, userId: userId, deviceId: deviceId)
    }
}
