//
//  Auth.swift
//  StitchCore
//
//  Created by Jason Flax on 10/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public class Auth {
    public let userId: String

    internal var authInfo: AuthInfo

    private let stitchClient: StitchClient

    // Initializes new Auth resource
    // - parameter stitchClient: associated stitch client
    // - parameter authInfo: information about the logged in status
    internal init(stitchClient: StitchClient,
                  authInfo: AuthInfo) {
        self.stitchClient = stitchClient
        self.authInfo = authInfo
        self.userId = authInfo.userId
    }

    public func createApiKey(name: String) -> StitchTask<ApiKey> {
        return stitchClient.performRequest(method: .post,
                                           endpoint: Consts.UserProfileApiKeyPath,
                                           parameters: ["name": name],
                                           refreshOnFailure: true,
                                           useRefreshToken: true,
                                           responseType: ApiKey.self)
    }

    public func fetchApiKey(id: String) -> StitchTask<ApiKey> {
        return stitchClient.performRequest(method: .get,
                                           endpoint: "\(Consts.UserProfileApiKeyPath)/\(id)",
            refreshOnFailure: true,
            useRefreshToken: true,
            responseType: ApiKey.self)
    }

    public func fetchApiKeys() -> StitchTask<[ApiKey]> {
        return stitchClient.performRequest(method: .get,
                                           endpoint: "\(Consts.UserProfileApiKeyPath)",
                                           refreshOnFailure: true,
                                           useRefreshToken: true,
                                           responseType: [ApiKey].self)
    }

    public func deleteApiKey(id: String) -> StitchTask<Bool> {
        return stitchClient.performRequest(method: .delete,
                                           endpoint: "\(Consts.UserProfileApiKeyPath)/\(id)",
                                           refreshOnFailure: true,
                                           useRefreshToken: true,
                                           responseType: Bool.self)
    }

    private func enableDisableApiKey(id: String, shouldEnable: Bool) -> StitchTask<Bool> {
        return stitchClient.performRequest(method: .put,
                                           endpoint: Consts.UserProfileApiKeyPath +
                                              "\(id)/\(shouldEnable ? "enable" : "disable")",
                                           refreshOnFailure: true,
                                           useRefreshToken: true,
                                           responseType: Bool.self)
    }

    public func enableApiKey(id: String) ->  StitchTask<Bool> {
        return self.enableDisableApiKey(id: id, shouldEnable: true)
    }

    public func disableApiKey(id: String) -> StitchTask<Bool> {
        return self.enableDisableApiKey(id: id, shouldEnable: false)
    }
    /**
     Fetch the current user profile, containing all user info. Can fail.
     
     - Returns: A StitchTask containing profile of the given user
     */
    @discardableResult
    public func fetchUserProfile() -> StitchTask<UserProfile> {
        return stitchClient.performRequest(method: .get,
                                           endpoint: Consts.UserProfilePath,
                                           refreshOnFailure: false,
                                           useRefreshToken: false,
                                           responseType: UserProfile.self)
            .response(onQueue: DispatchQueue.global(qos: .utility)) { _ in }
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
        if let exp = self.authInfo.accessToken?.expiration {
            return Date() >= (exp - TimeInterval(withinSeconds))
        }
        return nil
    }
}
