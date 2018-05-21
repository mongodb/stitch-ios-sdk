// swiftlint:disable force_try
import XCTest
@testable import StitchCore
import BSON

import func JWT.encode
import enum JWT.Algorithm
import class JWT.ClaimSetBuilder

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
    "user_id": ObjectId.NewObjectId().hexString,
    "device_id": ObjectId.NewObjectId().hexString
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
}
