// swiftlint:disable force_try
// swiftlint:disable force_cast
// swiftlint:disable nesting
// swiftlint:disable file_length
// swiftlint:disable function_body_length
// swiftlint:disable type_body_length
import XCTest
import MockUtils
import MongoSwift
@testable import StitchCoreSDK
import StitchCoreSDKMocks
import Swifter

import func JWT.encode
import enum JWT.Algorithm

private let baseJSONHeaders = [
    Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue
]

private let testAccessToken = encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
    var date = Date()
    $0.issuedAt = date.addingTimeInterval(-1000)
    $0.expiration = date.addingTimeInterval(1000)
}

private let testRefreshToken = encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
    var date = Date()
    $0.issuedAt = date.addingTimeInterval(-1000)
}

/**
 * Gets a login response for testing that is always the same.
 */
private var lastUserId: Int = 0
private var lastDeviceId: Int = 0
private func getTestLoginResponse() -> Response {
    lastUserId += 1
    lastDeviceId += 1
    let resp = APIAuthInfoImpl.init(
        userID: "userid-\(lastUserId)",
        deviceID: "deviceid-\(lastDeviceId)",
        accessToken: testAccessToken,
        refreshToken: testRefreshToken
    )
    return getTestResponse(forResponseData: try! JSONEncoder().encode(resp))
}

private let testLoginResponse = APIAuthInfoImpl.init(
    userID: "userid-\(lastUserId)",
    deviceID: "deviceids-\(lastDeviceId)",
    accessToken: testAccessToken,
    refreshToken: testRefreshToken
)

/**
 * A user profile for testing that is always the same.
 */
private let testUserProfile = APICoreUserProfileImpl.init(
    userType: "normal",
    identities: [APIStitchUserIdentity.init(id: "bar", providerType: "baz")],
    data: APIExtendedUserProfileImpl.init()
)

/**
 * A link response for testing that is always the same.
 */
private let testLinkResponse = APIAuthInfoImpl.init(
    userID: "some-unique-user-id",
    deviceID: "0123456012345601234560123456",
    accessToken: testAccessToken,
    refreshToken: nil
)

private func getTestResponse(forResponseData responseData: Data?) -> Response {
    return Response.init(statusCode: 200,
                         headers: baseJSONHeaders,
                         body: responseData)

}

func getMockedRequestClient() -> MockStitchRequestClient {
    let requestClient = MockStitchRequestClient.init()

    // Any /login works
    requestClient.doRequestMock.doReturn(
        resultFunc: getTestLoginResponse,
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/login")
        })

    )

    // Profile works if the access token is the same as the above
    requestClient.doRequestMock.doReturn(
        result: getTestResponse(forResponseData: try! JSONEncoder().encode(testUserProfile)),
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/profile")
        })
    )

    // Link works if the access token is the same as the above
    requestClient.doRequestMock.doReturn(
        result: getTestResponse(forResponseData: try! JSONEncoder().encode(testLinkResponse)),
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/login?link=true")
        })
    )

    // return a 204 on session delete requests
    requestClient.doRequestMock.doReturn(
        result: Response.init(statusCode: 204, headers: [:], body: nil),
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/session") && req.method == .delete
        })
    )

    return requestClient
}

class CoreStitchAuthUnitTests: StitchXCTestCase {
    private final class StitchAuth: CoreStitchAuth<CoreStitchUserImpl> {
        init(requestClient: StitchRequestClient,
             authRoutes: StitchAuthRoutes,
             storage: Storage) throws {
            try super.init(requestClient: requestClient,
                       authRoutes: authRoutes,
                       storage: storage,
                       startRefresherThread: false
            )
        }

        public final override var userFactory: AnyStitchUserFactory<CoreStitchUserImpl> {
            return AnyStitchUserFactory.init {(id, providerType, providerName, prof, loggedIn, lastAuthActivity)
                -> CoreStitchUserImpl in
                return CoreStitchUserImpl.init(
                    id: id,
                    loggedInProviderType: providerType,
                    loggedInProviderName: providerName,
                    profile: prof,
                    isLoggedIn: loggedIn,
                    lastAuthActivity: lastAuthActivity)
            }
        }
        // swiftlint:enable line_length

        public final override func onAuthEvent() { }
    }

    func testLoginInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        let user = try auth.loginInternal(withCredential: AnonymousCredential())
        let profile = testUserProfile

        XCTAssertEqual("userid-\(lastUserId)", user.id)
        XCTAssertEqual(AnonymousAuthProvider.defaultName, user.loggedInProviderName)
        XCTAssertEqual(StitchProviderType.anonymous, user.loggedInProviderType)
        XCTAssertEqual(profile.userType, user.userType)
        XCTAssertEqual(profile.identities[0].id, user.identities[0].id)
        XCTAssertEqual(auth.user?.id, user.id)

        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 2, forArg: .any))

        let expectedRequest: StitchDocRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: routes.authProviderLoginRoute(withProviderName: AnonymousAuthProvider.defaultName))
            .with(document: ["options": ["device": Document.init()] as Document])

        XCTAssertEqual(try expectedRequest.build() as StitchRequest,
                       requestClient.doRequestMock.capturedInvocations[0])

        let expectedRequest2: StitchRequestBuilder = StitchRequestBuilder()
            .with(method: .get)
            .with(path: routes.profileRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testAccessToken)])

        XCTAssertEqual(try expectedRequest2.build(),
                       requestClient.doRequestMock.capturedInvocations[1])

    }

    func testIsLoggedIn() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        XCTAssertFalse(auth.isLoggedIn)
        _ = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.isLoggedIn)
    }

    func testHasDeviceID() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        XCTAssertFalse(auth.hasDeviceId)

        _ = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.hasDeviceId)
    }

    func testMultipleLogins() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        // Should initially have 0 listed users
        XCTAssertEqual(auth.listUsersInternal().count, 0)
        XCTAssertFalse(auth.isLoggedIn)

        // After login, there whould be 1 user and it should also be the active user
        let user1 = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 1)
        XCTAssertEqual(user1.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.listUsersInternal()[0].id, "userid-\(lastUserId)")
        XCTAssertTrue(auth.listUsersInternal()[0].isLoggedIn)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.loggedInProviderType, StitchProviderType.anonymous)
        XCTAssertEqual(auth.activeUser?.loggedInProviderName, AnonymousAuthProvider.defaultName)

        // Insert another user and there must now be 2 users returned by listUsersInternal() and the
        // new user is guaranteed to be the last user in the list
        let currNumUsers = lastUserId
        let user2 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(user2.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.listUsersInternal()[1].id, "userid-\(lastUserId)")
        XCTAssertTrue(auth.listUsersInternal()[1].isLoggedIn)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.loggedInProviderType, StitchProviderType.userPassword)

        // If we login with the exact same credentials then there should still be 2 users in listUsersInternal()
        lastUserId = currNumUsers // have to fake the response to give the same userId
        lastDeviceId = currNumUsers
        let user3 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(user3.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.listUsersInternal()[1].id, "userid-\(lastUserId)")
        XCTAssertTrue(auth.listUsersInternal()[1].isLoggedIn)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, "userid-\(lastUserId)")

        // If we login again with anonymous credentials then we should reuse the existing session and not create
        // a new user
        let user4 = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(user4.id, "userid-\(currNumUsers)")
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, "userid-\(currNumUsers)")
        XCTAssertEqual(auth.activeUser?.id, "userid-\(currNumUsers)")
        XCTAssertEqual(auth.activeUser?.loggedInProviderType, StitchProviderType.anonymous)

        // Logging in with a new set of credentials should increase the number of users to 3
        let user5 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo2@bar.com", withPassword: "foobar"))
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 3)
        XCTAssertEqual(user5.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.listUsersInternal()[2].id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.id, "userid-\(lastUserId)")
        XCTAssertEqual(auth.activeUser?.loggedInProviderType, StitchProviderType.userPassword)

        // Should have only run 4 times (4 x 2 = 8)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 8, forArg: .any))
    }

    func testLinkUserInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        let user = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 2, forArg: .any))

        let linkedUser = try auth.linkUserInternal(
            withUser: user,
            withCredential: UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar")
        )

        XCTAssertEqual(linkedUser.id, testLinkResponse.userID )

        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 4, forArg: .any))

        let deviceId = "deviceid-" + user.id.split(separator: "-")[1]
        let expectedRequest = StitchRequestBuilder()
            .with(method: .post)
            .with(path: routes.authProviderLinkRoute(withProviderName: UserPasswordAuthProvider.defaultName))
            .with(body: ("{ \"username\" : \"foo@bar.com\", \"password\" : \"foobar\"," +
                         " \"options\" : { \"device\" : { \"deviceId\" : \"\(deviceId)\" } } }")
                        .data(using: .utf8)!)
            .with(headers: [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue,
                            Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testAccessToken)])

        XCTAssertEqual(try expectedRequest.build(), requestClient.doRequestMock.capturedInvocations[2])

        let expectedRequest2 = StitchRequestBuilder()
            .with(method: .get)
            .with(path: routes.profileRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testAccessToken)])

        XCTAssertEqual(try expectedRequest2.build(), requestClient.doRequestMock.capturedInvocations[3])
    }

    func testLogoutInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        // Create and login with 3 users
        let user1 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        let user2 = try auth.loginInternal(withCredential: AnonymousCredential())
        _ = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "bar@biz", withPassword: "fizzbuzz"))
        let user4 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "bar@bar", withPassword: "fizzbuzz"))

        // Verify current auth state has 3 users with user 3as the active user
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user4.id)

        // Logout the current user
        XCTAssertNoThrow(try auth.logoutInternal(withId: nil))
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertFalse(auth.listUsersInternal()[3].isLoggedIn)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 9, forArg: .any))

        // Logout a specific user
        XCTAssertNoThrow(try auth.logoutInternal(withId: user1.id))
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertFalse(auth.listUsersInternal()[0].isLoggedIn)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 10, forArg: .any))

        // Logging out of the active user when there is no active user should still pass
        XCTAssertNoThrow(try auth.logoutInternal(withId: nil))
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 10, forArg: .any))

        // Logout of an existing but not logged in user should pass and not change anything
        XCTAssertNoThrow(try auth.logoutInternal(withId: user1.id))
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 10, forArg: .any))

        // Logout of a user with a nonexistant userId should throw UserNotFound
        do {
            try auth.logoutInternal(withId: "not-a-real-user-id")
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .clientError(_) = err else {
                    XCTFail("logoutInternal returned an incorrect error type")
                    return
                }
                XCTAssertEqual("userNotFound", err.description)
            }
        }

        // Logging out of an anonymous user should delete the user record
        XCTAssertNoThrow(try auth.logoutInternal(withId: user2.id))
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 3)

        let expectedRequest = StitchRequestBuilder()
            .with(method: .delete)
            .with(path: routes.sessionRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testRefreshToken)])
        XCTAssertEqual(try expectedRequest.build(), requestClient.doRequestMock.capturedInvocations[8])
    }

    func testSwitchToUser() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        // Create and login with 3 users
        let user1 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        let user2 = try auth.loginInternal(withCredential: AnonymousCredential())

        // Verify current auth state has 2 users with user2 as the active user
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user2.id)

        // Switch to user1 should succeed
        let newUser = try auth.switchToUserInternal(withId: user1.id)
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user1.id)
        XCTAssertEqual(auth.activeUser?.id, user1.id)
        XCTAssertEqual(newUser.id, user1.id)

        // Logout of active user
        try auth.logoutInternal(withId: nil)
        XCTAssertFalse(auth.isLoggedIn)

        // Switch to user 2 should succeed
        let newUser2 = try auth.switchToUserInternal(withId: user2.id)
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user2.id)
        XCTAssertEqual(auth.activeUser?.id, user2.id)
        XCTAssertEqual(newUser2.id, user2.id)

        // Switch to a non-existant user should fail and leave the auth state unchanged
        do {
            _ = try auth.switchToUserInternal(withId: "not-a-real-user-id")
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .clientError(_) = err else {
                    XCTFail("logoutInternal returned an incorrect error type")
                    return
                }
                XCTAssertEqual("userNotFound", err.description)
                XCTAssertTrue(auth.isLoggedIn)
                XCTAssertEqual(auth.listUsersInternal().count, 2)
                XCTAssertEqual(auth.activeUserAuthInfo?.userId, user2.id)
                XCTAssertEqual(auth.activeUser?.id, user2.id)
            }
        }

        // Switch to existing user that is not logged in should throw
        do {
            _ = try auth.switchToUserInternal(withId: user1.id)
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .clientError(_) = err else {
                    XCTFail("logoutInternal returned an incorrect error type")
                    return
                }
                XCTAssertEqual("userNoLongerValid", err.description)
                XCTAssertTrue(auth.isLoggedIn)
                XCTAssertEqual(auth.listUsersInternal().count, 2)
                XCTAssertEqual(auth.activeUserAuthInfo?.userId, user2.id)
                XCTAssertEqual(auth.activeUser?.id, user2.id)
            }
        }

    }

    func testRemoveUserWithId() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        // Create and login with 2 users
        let user1 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        let user2 = try auth.loginInternal(withCredential: AnonymousCredential())
        let user3 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bizbar.co", withPassword: "foobar"))

        // Verify current auth state has 2 users with user2 as the active user
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 3)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user3.id)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 6, forArg: .any))

        // Remove the current user
        try auth.removeUserInternal(withId: nil)
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertEqual(auth.listUsersInternal()[0].id, user1.id)
        XCTAssertEqual(auth.listUsersInternal()[1].id, user2.id)

        // Removing a non-existent user id should throw and leave the auth state un-changed
        do {
            try auth.removeUserInternal(withId: "not-a-real-user-id")
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .clientError(_) = err else {
                    XCTFail("logoutInternal returned an incorrect error type")
                    return
                }
                XCTAssertEqual("userNotFound", err.description)
                XCTAssertFalse(auth.isLoggedIn)
                XCTAssertEqual(auth.listUsersInternal().count, 2)
                XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 7, forArg: .any))
            }
        }

        // Logout user 1
        XCTAssertNoThrow(try auth.logoutInternal(withId: user1.id))
        XCTAssertEqual(auth.listUsersInternal().count, 2)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 8, forArg: .any))

        // Removing a user that is logged out should not send logout request to server
        XCTAssertNoThrow(try auth.removeUserInternal(withId: user1.id))
        XCTAssertEqual(auth.listUsersInternal().count, 1)
        XCTAssertEqual(auth.listUsersInternal()[0].id, user2.id)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 8, forArg: .any))

        // Removing active user when there is no active user should not change anything
        XCTAssertNoThrow(try auth.removeUserInternal(withId: nil))
        XCTAssertEqual(auth.listUsersInternal().count, 1)
    }

    func testAuthPersistence() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let storage = MemoryStorage.init()

        var auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )

        // Create and login with 3 users
        let user1 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))
        let user2 = try auth.loginInternal(withCredential: AnonymousCredential())
        let user3 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "bar@biz", withPassword: "fizzbuzz"))
        let user4 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "bar@bar", withPassword: "fizzbuzz"))

        // Verify current auth state has 3 users with user 3as the active user
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user4.id)

        // Logout the third user
        XCTAssertNoThrow(try auth.logoutInternal(withId: user3.id))
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertFalse(auth.listUsersInternal()[2].isLoggedIn)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 9, forArg: .any))

        // Simulate re-starting the app
        auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )

        // Verify the state of the auth information
        XCTAssertEqual(auth.listUsersInternal().count, 4)
        XCTAssertEqual(auth.listUsersInternal()[0].id, user1.id)
        XCTAssertTrue(auth.listUsersInternal()[0].isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal()[1].id, user2.id)
        XCTAssertTrue(auth.listUsersInternal()[1].isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal()[2].id, user3.id)
        XCTAssertFalse(auth.listUsersInternal()[2].isLoggedIn)
        XCTAssertEqual(auth.listUsersInternal()[3].id, user4.id)
        XCTAssertTrue(auth.listUsersInternal()[3].isLoggedIn)

        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertNotNil(auth.activeUserAuthInfo)
        XCTAssertNotNil(auth.activeUser)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user4.id)
        XCTAssertTrue(auth.activeUserAuthInfo?.isLoggedIn ?? false)
        XCTAssertEqual(auth.activeUser?.id, user4.id)
        XCTAssertTrue(auth.activeUser?.isLoggedIn ?? false)
    }

    func testHandleAuthFailure() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        let user = try auth.loginInternal(withCredential: AnonymousCredential())

        let refreshedToken = encode(Algorithm.hs256("refreshedJWT".data(using: .utf8)!)) {
            let date = Date()
            $0.issuedAt = date.addingTimeInterval(-1000)
            $0.expiration = date.addingTimeInterval(1000)

        }

        requestClient.doRequestMock.doReturn(
            result: Response.init(statusCode: 200,
                                  headers: baseJSONHeaders,
                                  body: (["access_token": refreshedToken] as Document)
                                    .canonicalExtendedJSON.data(using: .utf8)),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                return req.path.hasSuffix("/session") && req.method == .post
            })
        )

        // Sequences of events for the matcher for multi-arg functions are not yet implemented
        // so using this workaround. yay for closure capture!
        var didThrowOnce: Bool = false
        requestClient.doRequestMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .invalidSession),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                if !didThrowOnce {
                    if req.path.hasSuffix("/login?link=true") {
                        didThrowOnce = true
                        return true
                    }
                }
                return false
            })
        )

        requestClient.doRequestMock.doReturn(
            result: getTestResponse(forResponseData: try! JSONEncoder().encode(testLinkResponse)),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                return req.path.hasSuffix("/login?link=true")
            })
        )

        let linkedUser = try auth.linkUserInternal(
            withUser: user,
            withCredential: UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar")
        )

        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 6, forArg: .any))

        // check for the session POST to get a new access token
        let expectedRequest = StitchRequestBuilder()
            .with(method: .post)
            .with(path: routes.sessionRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testRefreshToken)])

        XCTAssertEqual(try expectedRequest.build(), requestClient.doRequestMock.capturedInvocations[3])

        // check for the retried link request
        let expectedRequest2 = StitchRequestBuilder()
            .with(method: .post)
            .with(path: routes.authProviderLinkRoute(withProviderName: UserPasswordAuthProvider.defaultName))
            .with(body: ("{ \"username\" : \"foo@bar.com\", \"password\" : \"foobar\"," +
                " \"options\" : { \"device\" : { \"deviceId\" : \"deviceid-\(lastDeviceId)\" } } }")
                .data(using: .utf8)!)
            .with(headers: [Headers.contentType.rawValue: ContentTypes.applicationJSON.rawValue,
                            Headers.authorization.rawValue: Headers.authorizationBearer(forValue: refreshedToken)])
        XCTAssertEqual(try expectedRequest2.build(), requestClient.doRequestMock.capturedInvocations[4])
        XCTAssertTrue(auth.isLoggedIn)

        // This should log the user out
        didThrowOnce = false
        requestClient.doRequestMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .invalidSession),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                return req.method == .post && req.path.hasSuffix("/session")
            })
        )

        do {
            _ = try auth.linkUserInternal(
                withUser: linkedUser,
                withCredential: UserPasswordCredential(withUsername: "foo2@bar.com", withPassword: "foo2bar")
            )
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .serviceError(_, let errorCode) = err else {
                    XCTFail("linkUserInternal returned an incorrect error type")
                    return
                }
                XCTAssertEqual(errorCode, .invalidSession)
            }
        }

        XCTAssertFalse(auth.isLoggedIn)
    }

    private struct CustomType: Decodable {
        enum CodingKeys: String, CodingKey {
            case id = "_id", intValue
        }

        let id: ObjectId
        let intValue: Int
    }

    func testDoAuthenticatedRequest() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        _ = try auth.loginInternal(withCredential: AnonymousCredential())

        let reqBuilder = StitchAuthDocRequestBuilder()
            .with(path: "giveMeData")
            .with(document: Document())
            .with(method: .post)

        let rawInt = "{ \"$numberInt\" : \"42\"}"

        // Check that primitive types can be decoded.
        requestClient.doRequestMock.doReturn(
            result: Response.init(statusCode: 200, headers: baseJSONHeaders, body: rawInt.data(using: .utf8)),
            forArg: .any
        )

        let intResult: Int = try auth.doAuthenticatedRequest(reqBuilder.build())
        XCTAssertEqual(42, intResult)

        // Check that the proper exceptions are thrown when decoding into the incorrect type.
        do {
            let _: String = try auth.doAuthenticatedRequest(reqBuilder.build())
            XCTFail("Should not have been able to decode extended JSON int into string.")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .requestError(_, let errorCode) = err else {
                    XCTFail("doAuthenticatedRequest returned an incorrect error type")
                    return
                }
                XCTAssertEqual(errorCode, .decodingError)
            }
        }

        // Check that BSON documents returned as extended JSON can be decoded
        let expectedObjectId = ObjectId()
        let docRaw = """
        {
            "_id": {
                "$oid": "\(expectedObjectId.description)"
            },
            "intValue": {
                "$numberInt": "42"
            }
        }
        """

        requestClient.doRequestMock.clearStubs()
        requestClient.doRequestMock.doReturn(
            result: Response(statusCode: 200, headers: baseJSONHeaders, body: docRaw.data(using: .utf8)),
            forArg: .any
        )

        let documentResult: Document = try auth.doAuthenticatedRequest(reqBuilder.build())
        XCTAssertEqual(expectedObjectId, documentResult["_id"] as! ObjectId)
        XCTAssertEqual(42, documentResult["intValue"] as! Int)

        let customObjResult: CustomType = try auth.doAuthenticatedRequest(reqBuilder.build())
        XCTAssertEqual(expectedObjectId, customObjResult.id)
        XCTAssertEqual(42, customObjResult.intValue)

        // Check that BSON arrays can be decoded
        let arrFromServer = ["hello", "world"]
        let arrFromServerRaw = "[\"hello\", \"world\"]"

        requestClient.doRequestMock.clearStubs()
        requestClient.doRequestMock.doReturn(
            result: Response(statusCode: 200, headers: baseJSONHeaders, body: arrFromServerRaw.data(using: .utf8)),
            forArg: .any
        )

        let listResult: [String] = try auth.doAuthenticatedRequest(reqBuilder.build())

        XCTAssertEqual(arrFromServer, listResult)
    }

    func testProfileRequestFailureEdgeCases() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )

        var profileRequestShouldFail = true

        // Profile request does not work when `profileRequestShouldFail` is true
        requestClient.doRequestMock.doThrow(
            error: StitchError.requestError(
                withError: MongoError.invalidResponse(), // placeholder error
                withRequestErrorCode: StitchRequestErrorCode.unknownError),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                if profileRequestShouldFail && req.path.contains("profile") {
                    return true
                }
                return false
            })
        )

        // Scenario 1: User is logged out -> attempts login -> initial login succeeds -> profile request fails
        //                                -> user is logged out

        do {
            _ = try auth.loginInternal(withCredential: AnonymousCredential())
            XCTFail("expected login to fail because of profile request")
        } catch {
            // do nothing
        }

        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertNil(auth.activeUserAuthInfo?.userId)
        XCTAssertNil(auth.user)

        // Scenario 2: User is logged in -> attempts login into other account -> initial login succeeds
        //                               -> profile request fails -> original user is logged out
        profileRequestShouldFail = false
        let user1 = try auth.loginInternal(withCredential: AnonymousCredential())
        XCTAssertNotNil(user1)

        profileRequestShouldFail = true
        do {
            _ = try auth.loginInternal(
                withCredential: UserPasswordCredential.init(withUsername: "foo", withPassword: "bar")
            )
            XCTFail("expected subsequent login to fail because of profile request")
        } catch {
            // do nothing
        }

        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertEqual(auth.activeUser?.id, user1.id)
        XCTAssertEqual(auth.activeUserAuthInfo?.userId, user1.id)

        // Scenario 3: User is logged in -> attempt to link to other identity -> initial link request succeeds
        //                               -> profile request fails -> error thrown -> original user is still logged in
        //                               -> edge case: in this case the auth provider type should be user/password

        profileRequestShouldFail = false
        let userToBeLinked = try auth.loginInternal(withCredential: AnonymousCredential())

        profileRequestShouldFail = true
        do {
            _ = try auth.linkUserInternal(
                withUser: auth.activeUser!,
                withCredential: UserPasswordCredential.init(withUsername: "hello", withPassword: "friend")
            )
            XCTFail("expected link request to fail because of profile request")
        } catch {
            // do nothing
        }

        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertNotNil(auth.activeUserAuthInfo)
        XCTAssertEqual(userToBeLinked.id, auth.user!.id)
        XCTAssertEqual(auth.activeUserAuthInfo?.loggedInProviderType, StitchProviderType.userPassword)
        XCTAssertEqual(auth.activeUserAuthInfo?.loggedInProviderName, UserPasswordAuthProvider.defaultName)
    }

    func testDeviceIdPersistence() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let storage = MemoryStorage.init()

        var auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )

        // Should not be a device id yet
        XCTAssertNil(auth.deviceId)

        // Create and login with 3 users
        _ = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))

        // Device id should not be null
        XCTAssertNotNil(auth.deviceId)

        // After logout device id should still exist
        try auth.logoutInternal(withId: nil)
        XCTAssertNotNil(auth.deviceId)

        _ = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))

        // After remove, device id should still exist
        try auth.removeUserInternal(withId: nil)
        XCTAssertNotNil(auth.deviceId)
        auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )
        XCTAssertNotNil(auth.deviceId)

        // After logout the device id should persist
        _ = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foosss@bar.com", withPassword: "foobar"))
        try auth.logoutInternal(withId: nil)
        XCTAssertNotNil(auth.deviceId)
        auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )
        XCTAssertNotNil(auth.deviceId)

    }

    func testLastAuthEvent() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let storage = MemoryStorage.init()

        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: storage
        )

        let time1 = Date.init().timeIntervalSince1970

        // Create and login with users
        let user1 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar"))

        let time2 = Date.init().timeIntervalSince1970
        XCTAssertGreaterThanOrEqual(user1.lastAuthActivity, time1)
        XCTAssertLessThanOrEqual(user1.lastAuthActivity, time2)

        // Create and login with users
        let user2 = try auth.loginInternal(withCredential:
            UserPasswordCredential(withUsername: "foo2@bar.com", withPassword: "foobar2"))

        let time3 = Date.init().timeIntervalSince1970
        XCTAssertGreaterThanOrEqual(user2.lastAuthActivity, time2)
        XCTAssertLessThanOrEqual(user2.lastAuthActivity, time3)

        var users = auth.listUsersInternal()
        XCTAssertGreaterThanOrEqual(users[1].lastAuthActivity, users[0].lastAuthActivity)

        _ = try auth.switchToUserInternal(withId: user1.id)
        users = auth.listUsersInternal()
        XCTAssertGreaterThanOrEqual(users[0].lastAuthActivity, users[1].lastAuthActivity)
    }
}
