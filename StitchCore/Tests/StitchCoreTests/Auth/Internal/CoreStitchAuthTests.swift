// swiftlint:disable force_try
import XCTest
import MongoSwift
import Swifter
@testable import StitchCore

import func JWT.encode
import enum JWT.Algorithm



//private let appRoutes = StitchAppRoutes.init(clientAppId: "")
//private let userId = ObjectId().description
//private let mockApiAuthInfo = [
//    "user_id": userId,
//    "device_id": ObjectId().description,
//    "access_token": encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
//        var date = Date()
//        date.addTimeInterval(1000)
//        $0.expiration = date
//    },
//    "refresh_token": encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
//        var date = Date()
//        date.addTimeInterval(1000)
//        $0.expiration = date
//    }
//]
//
//private let mockApiAuthInfoForLinkRequest = [
//    "user_id": userId,
//    "access_token": encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
//        var date = Date()
//        date.addTimeInterval(1000)
//        $0.expiration = date
//    }
//]
//
//private let mockApiAccessToken = [
//    "access_token": encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
//        var date = Date()
//        date.addTimeInterval(1000)
//        $0.expiration = date
//    }
//]
//
//private let baseJSONHeaders = [
//    Headers.contentType.rawValue: ContentTypes.applicationJson.rawValue
//]
//
//private let mockAPIProfile: [String: Any] = [
//    "type": "foo",
//    "identities": [
//        ["id": "bar",
//         "provider_type": "baz"]
//    ],
//    "data": [String: String]()
//]
//
//final class MockStitchRequestClient: StitchRequestClient {
//    var handleAuthProviderLoginRoute: () throws -> Response = {
//        Response.init(statusCode: 200,
//                      headers: baseJSONHeaders,
//                      body: try! JSONEncoder().encode(mockApiAuthInfo))
//    }
//
//    var handleAuthProviderLinkRoute: () throws -> Response = {
//        Response.init(statusCode: 200,
//                      headers: baseJSONHeaders,
//                      body: try! JSONEncoder().encode(mockApiAuthInfoForLinkRequest))
//    }
//
//    var handleProfileRoute: () throws -> Response = {
//        Response.init(statusCode: 200,
//                      headers: baseJSONHeaders,
//                      body: try! JSONSerialization.data(withJSONObject: mockAPIProfile))
//    }
//
//    var handleSessionRoute: () throws -> Response = {
//        Response.init(statusCode: 200,
//                      headers: baseJSONHeaders,
//                      body: try! JSONEncoder().encode(mockApiAccessToken))
//    }
//
//    init() { }
//    init(baseURL: String, transport: Transport, defaultRequestTimeout: TimeInterval) { }
//
//    private func checkAuth(headers: [String: String]) throws {
//        guard let authHeader = headers["Authorization"] else {
//            throw StitchError.serviceError(withMessage: "Invalid session authorization header",
//                                           withServiceErrorCode: .invalidSession)
//        }
//
//        let headerComponents = authHeader.split(separator: " ")
//        guard headerComponents[0] == "Bearer",
//              headerComponents.count == 2 else {
//                throw StitchError.serviceError(withMessage: "Invalid session authorization header",
//                                               withServiceErrorCode: .invalidSession)
//        }
//    }
//
//    private func mockResponse<R>(forRequest stitchReq: R) throws -> Response where R: StitchRequest {
//        switch stitchReq.path {
//        case appRoutes.authRoutes.authProviderLoginRoute(withProviderName: "anon-user"):
//            return try self.handleAuthProviderLoginRoute()
//        case appRoutes.authRoutes.authProviderLinkRoute(withProviderName: "local-userpass"):
//            try checkAuth(headers: stitchReq.headers)
//            return try self.handleAuthProviderLinkRoute()
//        case appRoutes.authRoutes.profileRoute:
//            try checkAuth(headers: stitchReq.headers)
//            return try self.handleProfileRoute()
//        case appRoutes.authRoutes.sessionRoute:
//            try checkAuth(headers: stitchReq.headers)
//            return try self.handleSessionRoute()
//        default:
//            throw StitchError.serviceError(withMessage: "404 page not found", withServiceErrorCode: .unknown)
//        }
//    }
//
//    func doRequest<R>(_ stitchReq: R) throws -> Response where R: StitchRequest {
//        return try mockResponse(forRequest: stitchReq)
//    }
//
//    func doJSONRequestRaw(_ stitchReq: StitchDocRequest) throws -> Response {
//        return try mockResponse(forRequest: stitchReq)
//    }
//}
//
//final class MockStitchUserFactory: StitchUserFactory {
//    typealias UserType = MockStitchUser
//
//    func makeUser(withId id: String,
//                  withLoggedInProviderType loggedInProviderType: StitchProviderType,
//                  withLoggedInProviderName loggedInProviderName: String,
//                  withUserProfile userProfile: StitchUserProfile) -> MockStitchUser {
//        return MockStitchUser.init(id: id,
//                                   loggedInProviderType: loggedInProviderType,
//                                   loggedInProviderName: loggedInProviderName,
//                                   profile: userProfile)
//    }
//}
//
//final class MockCoreStitchAuth: CoreStitchAuth<MockStitchUser> {
//    var setterAccessed = 0
//    override var authInfo: AuthInfo? {
//        didSet {
//            objc_sync_enter(self)
//            defer { objc_sync_exit(self) }
//            setterAccessed += 1
//        }
//    }
//
//    private var authDelegates = [() -> Void]()
//
//    override var userFactory: AnyStitchUserFactory<MockStitchUser> {
//        return AnyStitchUserFactory(stitchUserFactory: MockStitchUserFactory.init())
//    }
//
//    func addAuthDelegate(_ delegate: @escaping () -> Void) {
//        self.authDelegates.append(delegate)
//    }
//
//    override func onAuthEvent() {
//        authDelegates.forEach { $0() }
//    }
//
//    override var deviceInfo: Document {
//        return ["deviceInfoKey": "deviceInfoValue"]
//    }
//}
//

/**
 * Gets a login response for testing that is always the same.
 */
fileprivate let testLoginResponse = APIAuthInfoImpl.init(
    userId: "some-unique-user-id",
    deviceId: "0123456012345601234560123456",
    accessToken: "1234", // TODO: getTestAccessToken
    refreshToken: "1234" // TODO: getTestRefreshToken
)

/**
 * A user profile for testing that is always the same.
 */
fileprivate let userProfileResponse = APICoreUserProfileImpl.init(
    userType: "normal",
    identities: [APIStitchUserIdentity.init(id: "bar", providerType: "baz")],
    data: APIExtendedUserProfileImpl.init()
)

/**
 * A link response for testing that is always the same.
 */
fileprivate let testLinkResponse = APIAuthInfoImpl.init(
    userId: "some-unique-user-id",
    deviceId: "0123456012345601234560123456",
    accessToken: "1234", // TODO: getTestAccessToken
    refreshToken: nil
)
//    return new ApiAuthInfo(
//        "some-unique-user-id",
//        "0123456012345601234560123456",
//        getTestAccessToken(),
//        getTestRefreshToken());
//}

///**
// * Gets a link response for testing that is always the same.
// */
//public static ApiAuthInfo getTestLinkResponse() {
//    return new ApiAuthInfo(
//        "some-unique-user-id",
//        "0123456012345601234560123456",
//        getTestAccessToken(),
//        null);
//}

func getMockedRequestClient() -> MockStitchRequestClientProto {
    let requestClient = MockStitchRequestClientProto.init()

    // Any /login works
    requestClient.doRequestMock.doReturn(
        result: <#T##Response#>,
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/login")
        })
    )
    
    // Profile works if the access token is the same as the above
    requestClient.doRequestMock.doReturn(
        result: <#T##Response#>,
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/profile")
        })
    )
    
    // Link works if the access token is the same as the above
    requestClient.doRequestMock.doReturn(
        result: <#T##Response#>,
        forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
            return req.path.hasSuffix("/login?link=true")
        })
    )
    
//    // Any /login works
//    Mockito.doAnswer((ignored) -> new Response(getTestLoginResponse().toString()))
//        .when(requestClient)
//        .doRequest(ArgumentMatchers.argThat(req -> req.getPath().endsWith("/login")));
//
//    // Profile works if the access token is the same as the above
//    Mockito.doAnswer((ignored) -> new Response(getTestUserProfile().toString()))
//        .when(requestClient)
//        .doRequest(ArgumentMatchers.argThat(req -> req.getPath().endsWith("/profile")));
//
//    // Link works if the access token is the same as the above
//    Mockito.doAnswer((ignored) -> new Response(getTestLinkResponse().toString()))
//        .when(requestClient)
//        .doRequest(ArgumentMatchers.argThat(req -> req.getPath().endsWith("/login?link=true")));
    
    return requestClient
}

class CoreStitchAuthTests: StitchXCTestCase {
    
    func testLoginWithCredentialBlocking() throws {
        
    }
    
//    func testLoginWithCredentialBlocking() throws {
//        let coreStitchAuth = try! MockCoreStitchAuth.init(requestClient: MockStitchRequestClient.init(),
//                                                          authRoutes: appRoutes.authRoutes,
//                                                          storage: MemoryStorage())
//
//        let user = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//
//        XCTAssertEqual(user.id, userId)
//        XCTAssertEqual(user.loggedInProviderName, "anon-user")
//        XCTAssertEqual(user.loggedInProviderType.name, "anon-user")
//        XCTAssertEqual(user.profile.userType, "foo")
//        XCTAssert(user.profile.identities.first!.id == "bar")
//    }
//
//    func testLinkUserWithCredentialBlocking() throws {
//        let coreStitchAuth = try! MockCoreStitchAuth.init(requestClient: MockStitchRequestClient.init(),
//                                                          authRoutes: appRoutes.authRoutes,
//                                                          storage: MemoryStorage())
//
//        let user = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//        let linkedUser = try coreStitchAuth.linkUserWithCredentialBlocking(
//            withUser: user,
//            withCredential: UserPasswordCredential.init(withUsername: "foo@foo.com",
//                                                        withPassword: "bar")
//        )
//
//        XCTAssertEqual(linkedUser.id, user.id)
//    }
//
//    func testIsLoggedIn() throws {
//        let coreStitchAuth = try MockCoreStitchAuth.init(requestClient: MockStitchRequestClient(),
//                                                         authRoutes: appRoutes.authRoutes,
//                                                         storage: MemoryStorage())
//
//        _ = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//
//        XCTAssert(coreStitchAuth.isLoggedIn)
//    }
//
//    func testLogoutBlocking() throws {
//        let coreStitchAuth = try MockCoreStitchAuth.init(requestClient: MockStitchRequestClient(),
//                                                         authRoutes: appRoutes.authRoutes,
//                                                         storage: MemoryStorage())
//
//        XCTAssert(!coreStitchAuth.isLoggedIn)
//        _ = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//        XCTAssert(coreStitchAuth.isLoggedIn)
//
//        coreStitchAuth.logoutBlocking()
//        XCTAssert(!coreStitchAuth.isLoggedIn)
//    }
//
//    func testHasDeviceId() throws {
//        let coreStitchAuth = try MockCoreStitchAuth.init(requestClient: MockStitchRequestClient(),
//                                                     authRoutes: appRoutes.authRoutes,
//                                                     storage: MemoryStorage())
//
//        XCTAssert(!coreStitchAuth.hasDeviceId)
//        _ = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//        XCTAssert(coreStitchAuth.hasDeviceId)
//    }
//
//    func testHandleAuthFailure() throws {
//        let mockRequestClient = MockStitchRequestClient()
//        let coreStitchAuth = try MockCoreStitchAuth.init(requestClient: mockRequestClient,
//                                                         authRoutes: appRoutes.authRoutes,
//                                                         storage: MemoryStorage())
//
//        var oldLinkFunc = mockRequestClient.handleAuthProviderLinkRoute
//        mockRequestClient.handleAuthProviderLinkRoute = {
//            defer {
//                mockRequestClient.handleAuthProviderLinkRoute =
//                    oldLinkFunc
//            }
//            throw StitchError.serviceError(withMessage: "invalidSession",
//                                           withServiceErrorCode: .invalidSession)
//        }
//
//        let user = try coreStitchAuth.loginWithCredentialBlocking(withCredential: AnonymousCredential.init())
//        _ = try coreStitchAuth.linkUserWithCredentialBlocking(
//            withUser: user,
//            withCredential: UserPasswordCredential.init(withUsername: "foo@foo.com",
//                                                        withPassword: "bar"))
//
//        XCTAssertEqual(coreStitchAuth.setterAccessed, 3)
//    }
    
}
