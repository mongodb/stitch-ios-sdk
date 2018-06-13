import XCTest
import StitchCoreSDKMocks
@testable import StitchCoreSDK
import MongoSwift

import func JWT.encode
import enum JWT.Algorithm
import class JWT.ClaimSetBuilder

let freshJWT = encode(Algorithm.hs256("secret".data(using: .utf8)!), closure: { (csb: ClaimSetBuilder) in
    var date = Date()
    date.addTimeInterval(20*60)
    csb.expiration = date
})

let expiredJWT = encode(Algorithm.hs256("secret".data(using: .utf8)!), closure: { (csb: ClaimSetBuilder) in
    var date = Date()
    date.addTimeInterval(-(Date.init().timeIntervalSince1970 - 10000.0))
    csb.expiration = date
})

final class StubUser: CoreStitchUser {
    var id: String = ""
    
    var loggedInProviderType: StitchProviderType = .anonymous
    
    var loggedInProviderName: String = ""
    
    var userType: String = ""
    
    var profile: StitchUserProfile =
        StitchUserProfileImpl.init(userType: "", identities: [], data: APIExtendedUserProfileImpl.init())
    
    var identities: [StitchUserIdentity] = []
}

class AccessTokenRefresherUnitTests: XCTestCase {
    func testCheckRefresh() throws {
        let auth = MockCoreStitchAuth<StubUser>()
        let accessTokenRefresher = AccessTokenRefresher<StubUser>.init(authRef: auth)
        
        // Auth starts out logged in and with a fresh token
        let freshAuthInfo: AuthInfo = StoreAuthInfo.init(
            userID: "",
            deviceID: nil,
            accessToken: freshJWT,
            refreshToken: freshJWT,
            loggedInProviderType: .anonymous,
            loggedInProviderName: "",
            userProfile: StitchUserProfileImpl.init(userType: "",
                                                    identities: [],
                                                    data: APIExtendedUserProfileImpl.init()))
        
        auth.isLoggedInMock.doReturn(result: true)
        auth.getAuthInfoMock.doReturn(result: freshAuthInfo)
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 0))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 0))
        
        XCTAssertTrue(accessTokenRefresher.checkRefresh())
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 0))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 1))
        
        // Auth info is now expired
        let expiredAuthInfo: AuthInfo = StoreAuthInfo.init(
            userID: "",
            deviceID: nil,
            accessToken: expiredJWT,
            refreshToken: expiredJWT,
            loggedInProviderType: .anonymous,
            loggedInProviderName: "",
            userProfile: StitchUserProfileImpl.init(userType: "",
                                                    identities: [],
                                                    data: APIExtendedUserProfileImpl.init()))
        auth.getAuthInfoMock.doReturn(result: expiredAuthInfo)
        
        XCTAssertTrue(accessTokenRefresher.checkRefresh())
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 1))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 2))
        
        // Auth info is gone after checking is logged in
        auth.getAuthInfoMock.doReturn(result: nil)
        XCTAssertTrue(accessTokenRefresher.checkRefresh())
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 1))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 3))
        
        // CoreStitchAuth is ARCed
        var accessTokenRefresher2: AccessTokenRefresher<StubUser>!
        _ = {
            let auth2 = MockCoreStitchAuth<StubUser>()
            accessTokenRefresher2 = AccessTokenRefresher<StubUser>(authRef: auth2)
        }()
        
        XCTAssertFalse(accessTokenRefresher2.checkRefresh())
    }
}
