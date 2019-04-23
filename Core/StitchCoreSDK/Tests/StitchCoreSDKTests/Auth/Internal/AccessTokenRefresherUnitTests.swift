// swiftlint:disable function_body_length
// swiftlint:disable force_try

import XCTest
import StitchCoreSDKMocks
import MongoSwift
import SwiftJWT
@testable import StitchCoreSDK

var ufreshJWT = JWT<ClaimsStandardJWT>.init(claims: ClaimsStandardJWT.init(exp: Date().addingTimeInterval(20 * 60)))
let freshJWT = try! ufreshJWT.sign(using: JWTSigner.hs256(key: "secret".data(using: .utf8)!))

var uexpiredJWT = JWT<ClaimsStandardJWT>.init(
    claims: ClaimsStandardJWT.init(
        exp: Date().addingTimeInterval(-(Date.init().timeIntervalSince1970 - 10000.0))))
let expiredJWT = try! uexpiredJWT.sign(using: JWTSigner.hs256(key: "secret".data(using: .utf8)!))

final class StubUser: CoreStitchUser {
    var id: String = ""

    var loggedInProviderType: StitchProviderType = .anonymous

    var loggedInProviderName: String = ""

    var userType: String = ""

    var profile: StitchUserProfile =
        StitchUserProfileImpl.init(userType: "", identities: [], data: APIExtendedUserProfileImpl.init())

    var identities: [StitchUserIdentity] = []

    var isLoggedIn: Bool = false

    var lastAuthActivity: TimeInterval = Date.init().timeIntervalSince1970
}

class AccessTokenRefresherUnitTests: XCTestCase {
    func testCheckRefresh() throws {
        let auth = MockCoreStitchAuth<StubUser>()
        let accessTokenRefresher = AccessTokenRefresher<StubUser>.init(authRef: auth)

        // Auth starts out logged in and with a fresh token
        let freshAuthInfo: AuthInfo = AuthInfo.init(
            userID: "",
            deviceID: nil,
            accessToken: freshJWT,
            refreshToken: freshJWT,
            loggedInProviderType: .anonymous,
            loggedInProviderName: "",
            userProfile: StitchUserProfileImpl.init(userType: "",
                                                    identities: [],
                                                    data: APIExtendedUserProfileImpl.init()),
            lastAuthActivity: 0.0)

        auth.isLoggedInMock.doReturn(result: true)
        auth.getAuthInfoMock.doReturn(result: freshAuthInfo)
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 0))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 0))

        XCTAssertTrue(accessTokenRefresher.checkRefresh())
        XCTAssertTrue(auth.refreshAccessTokenMock.verify(numberOfInvocations: 0))
        XCTAssertTrue(auth.getAuthInfoMock.verify(numberOfInvocations: 1))

        // Auth info is now expired
        let expiredAuthInfo: AuthInfo = AuthInfo.init(
            userID: "",
            deviceID: nil,
            accessToken: expiredJWT,
            refreshToken: expiredJWT,
            loggedInProviderType: .anonymous,
            loggedInProviderName: "",
            userProfile: StitchUserProfileImpl.init(userType: "",
                                                    identities: [],
                                                    data: APIExtendedUserProfileImpl.init()),
            lastAuthActivity: 0.0)

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
