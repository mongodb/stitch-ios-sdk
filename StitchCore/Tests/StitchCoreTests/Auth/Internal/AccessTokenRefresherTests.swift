// swiftlint:disable force_try
import XCTest
@testable import StitchCore
import MongoSwift

import func JWT.encode
import enum JWT.Algorithm
import class JWT.ClaimSetBuilder

let freshJwt = encode(Algorithm.hs256("secret".data(using: .utf8)!), closure: { (csb: ClaimSetBuilder) in
    var date = Date()
    date.addTimeInterval(20*60)
    csb.expiration = date
})

let expiredJWT = encode(Algorithm.hs256("secret".data(using: .utf8)!), closure: { (csb: ClaimSetBuilder) in
    var date = Date()
    date.addTimeInterval(-(Date.init().timeIntervalSince1970 - 10000.0))
    csb.expiration = date
})

private let defaultMillis: UInt32 = 10
private let defaultMicros = defaultMillis * 1000

private let appRoutes = StitchAppRoutes.init(clientAppId: "")

let mockExpiredAuthInfo: Document = [
    "access_token": expiredJWT,
    "refresh_token": expiredJWT,
    "user_id": ObjectId().description,
    "device_id": ObjectId().description
]

class AccessTokenRefresherTests: XCTestCase {

    func testCheckRefresh() throws {
        let mockStitchRequestClient = MockStitchRequestClient.init()
        let mockCoreAuth = try! MockCoreStitchAuth.init(
            requestClient: mockStitchRequestClient,
            authRoutes: appRoutes.authRoutes,
            storage: MemoryStorage()
        )
        print(mockCoreAuth.setterAccessed)

        _ = try mockCoreAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
        print(mockCoreAuth.setterAccessed)

        let accessTokenRefresher = AccessTokenRefresher<MockStitchUser>.init(authRef: mockCoreAuth)

        accessTokenRefresher.checkRefresh()

        // setter should only have been accessed once for login
        XCTAssertEqual(mockCoreAuth.setterAccessed, 1)

        // swap out login route good data for expired data
        mockStitchRequestClient.handleAuthProviderLoginRoute = {
            Response.init(statusCode: 200,
                          headers: [:],
                          body: try! JSONEncoder().encode(mockExpiredAuthInfo))
        }

        // logout and relogin. setterAccessor should be accessed twice after this
        mockCoreAuth.logoutBlocking()
        _ = try mockCoreAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())

        // check refresh, which SHOULD trigger a refresh, and the setter
        accessTokenRefresher.checkRefresh()

        XCTAssertEqual(mockCoreAuth.setterAccessed, 3)
    }
    
    func testCheckRefreshProto() throws {
        let auth = MockCoreStitchAuthProto<StubUser>()
        let accessTokenRefresher = AccessTokenRefresher<StubUser>.init(authRef: auth)
        
        // Auth starts out logged in and with a fresh token
        let freshAuthInfo: AuthInfo = StoreAuthInfo.init(
            userId: "",
            deviceId: nil,
            accessToken: freshJwt,
            refreshToken: freshJwt,
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
            userId: "",
            deviceId: nil,
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
            let auth2 = MockCoreStitchAuthProto<StubUser>()
            accessTokenRefresher2 = AccessTokenRefresher<StubUser>(authRef: auth2)
        }()
        
        XCTAssertFalse(accessTokenRefresher2.checkRefresh())
    }
}
