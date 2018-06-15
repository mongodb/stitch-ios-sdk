// swiftlint:disable force_try
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

fileprivate let testAccessToken = encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
    var date = Date()
    $0.issuedAt = date.addingTimeInterval(-1000)
    $0.expiration = date.addingTimeInterval(1000)    
}

fileprivate let testRefreshToken = encode(Algorithm.hs256("foobar".data(using: .utf8)!)) {
    var date = Date()
    $0.issuedAt = date.addingTimeInterval(-1000)
}

/**
 * Gets a login response for testing that is always the same.
 */
fileprivate let testLoginResponse = APIAuthInfoImpl.init(
    userID: "some-unique-user-id",
    deviceID: "0123456012345601234560123456",
    accessToken: testAccessToken, // TODO: getTestAccessToken
    refreshToken: testRefreshToken // TODO: getTestRefreshToken
)

/**
 * A user profile for testing that is always the same.
 */
fileprivate let testUserProfile = APICoreUserProfileImpl.init(
    userType: "normal",
    identities: [APIStitchUserIdentity.init(id: "bar", providerType: "baz")],
    data: APIExtendedUserProfileImpl.init()
)

/**
 * A link response for testing that is always the same.
 */
fileprivate let testLinkResponse = APIAuthInfoImpl.init(
    userID: "some-unique-user-id",
    deviceID: "0123456012345601234560123456",
    accessToken: testAccessToken, // TODO: getTestAccessToken
    refreshToken: nil
)

fileprivate func getTestResponse(forResponseData responseData: Data?) -> Response {
    return Response.init(statusCode: 200,
                         headers: baseJSONHeaders,
                         body: responseData)
    
}

func getMockedRequestClient() -> MockStitchRequestClient {
    let requestClient = MockStitchRequestClient.init()

    // Any /login works
    requestClient.doRequestMock.doReturn(
        result: getTestResponse(forResponseData: try! JSONEncoder().encode(testLoginResponse)),
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
            return AnyStitchUserFactory.init { (id, providerType, providerName, profile) -> CoreStitchUserImpl in
                return CoreStitchUserImpl.init(
                    id: id,
                    loggedInProviderType: providerType,
                    loggedInProviderName: providerName,
                    profile: profile
                )
            }
        }
        
        public final override func onAuthEvent() { }
    }
    
    func testLoginWithCredentialInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        let user = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        let profile = testUserProfile
        
        XCTAssertEqual(testLoginResponse.userID, user.id)
        XCTAssertEqual(AnonymousAuthProvider.defaultName, user.loggedInProviderName)
        XCTAssertEqual(StitchProviderType.anonymous, user.loggedInProviderType)
        XCTAssertEqual(profile.userType, user.userType)
        XCTAssertEqual(profile.identities[0].id, user.identities[0].id)
        XCTAssertEqual(auth.user?.id, user.id)
        
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 2, forArg: .any))
        
        let expectedRequest: StitchDocRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: routes.authProviderLoginRoute(withProviderName: AnonymousAuthProvider.defaultName))
            .with(document: ["options": Document.init(["device": Document.init()])])
        
        XCTAssertEqual(try expectedRequest.build() as StitchRequest,
                       requestClient.doRequestMock.capturedInvocations[0])
        
        let expectedRequest2: StitchRequestBuilder = StitchRequestBuilder()
            .with(method: .get)
            .with(path: routes.profileRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testAccessToken)])
        
        XCTAssertEqual(try expectedRequest2.build(),
                       requestClient.doRequestMock.capturedInvocations[1])
        
    }
    
    func testLinkUserWithCredentialInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        let user = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 2, forArg: .any))
        
        let linkedUser = try auth.linkUserWithCredentialInternal(
            withUser: user,
            withCredential: UserPasswordCredential(withUsername: "foo@bar.com", withPassword: "foobar")
        )
        
        XCTAssertEqual(user.id, linkedUser.id)
        
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 4, forArg: .any))
        
        let expectedRequest = StitchRequestBuilder()
            .with(method: .post)
            .with(path: routes.authProviderLinkRoute(withProviderName: UserPasswordAuthProvider.defaultName))
            .with(body: ("{ \"username\" : \"foo@bar.com\", \"password\" : \"foobar\"," +
                         " \"options\" : { \"device\" : { \"deviceId\" : \"\(testLoginResponse.deviceID!)\" } } }")
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
    
    func testIsLoggedIn() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        XCTAssertFalse(auth.isLoggedIn)
        _ = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.isLoggedIn)
    }
    
    func testLogoutInternal() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        // return a 204 on session delete requests
        requestClient.doRequestMock.doReturn(
            result: Response.init(statusCode: 204, headers: [:], body: nil),
            forArg: Matcher<StitchRequest>.with(condition: { req -> Bool in
                return req.path.hasSuffix("/session") && req.method == .delete
            })
        )
        
        XCTAssertFalse(auth.isLoggedIn)
        _ = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.isLoggedIn)
        
        auth.logoutInternal()
        
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 3, forArg: .any))
        
        let expectedRequest = StitchRequestBuilder()
            .with(method: .delete)
            .with(path: routes.sessionRoute)
            .with(headers: [Headers.authorization.rawValue: Headers.authorizationBearer(forValue: testRefreshToken)])
        
        XCTAssertEqual(try expectedRequest.build(), requestClient.doRequestMock.capturedInvocations[2])
        
        XCTAssertFalse(auth.isLoggedIn)
    }
    
    func testHasDeviceID() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        XCTAssertFalse(auth.hasDeviceID)
        _ = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        XCTAssertTrue(auth.hasDeviceID)
    }
    
    func testHandleAuthFailure() throws {
        let requestClient = getMockedRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let auth = try StitchAuth.init(
            requestClient: requestClient,
            authRoutes: routes,
            storage: MemoryStorage.init()
        )
        
        let user = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        
        let refreshedToken = encode(Algorithm.hs256("refreshedJWT".data(using: .utf8)!)) {
            let date = Date()
            $0.issuedAt = date.addingTimeInterval(-1000)
            $0.expiration = date.addingTimeInterval(1000)
            
        }
        
        requestClient.doRequestMock.doReturn(
            result: Response.init(statusCode: 200,
                                  headers: baseJSONHeaders,
                                  body: Document.init(
                                    ["access_token": refreshedToken]
                                  ).canonicalExtendedJSON.data(using: .utf8)),
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
        
        let linkedUser = try auth.linkUserWithCredentialInternal(
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
                " \"options\" : { \"device\" : { \"deviceId\" : \"\(testLoginResponse.deviceID!)\" } } }")
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
            _ = try auth.linkUserWithCredentialInternal(
                withUser: linkedUser,
                withCredential: UserPasswordCredential(withUsername: "foo2@bar.com", withPassword: "foo2bar")
            )
            XCTFail("Error was not thrown where it was expected")
        } catch let error {
            let stitchError = error as? StitchError
            XCTAssertNotNil(error as? StitchError)
            if let err = stitchError {
                guard case .serviceError(_, let errorCode) = err else {
                    XCTFail("linkUserWithCredentialInternal returned an incorrect error type")
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
        
        _ = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        
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
                         "_id": { "$oid": "\(expectedObjectId.description)"},
                         "intValue": { "$numberInt": "42" }
                     }
                     """
        
        requestClient.doRequestMock.clearStubs()
        requestClient.doRequestMock.doReturn(
            result: Response(statusCode: 200, headers: baseJSONHeaders, body: docRaw.data(using: .utf8)),
            forArg: .any
        )
        
        let documentResult: Document = try auth.doAuthenticatedRequest(reqBuilder.build())
        XCTAssertEqual(expectedObjectId, try documentResult.get("_id"))
        XCTAssertEqual(42, try documentResult.get("intValue"))
        
        // Check that BSON documents returned as extended JSON can be decoded as a custom Decodable type
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
            forArg: .with(condition: { _ in
                return profileRequestShouldFail
            })
        )
        
        // Scenario 1: User is logged out -> attempts login -> initial login succeeds -> profile request fails
        //                                -> user is logged out
        
        do {
            _ = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
            XCTFail("expected login to fail because of profile request")
        } catch {
            // do nothing
        }
        
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertNil(auth.authInfo)
        XCTAssertNil(auth.user)
        
        // Scenario 2: User is logged in -> attempts login into other account -> initial login succeeds
        //                               -> profile request fails -> original user is logged out
        profileRequestShouldFail = false
        XCTAssertNotNil(try auth.loginWithCredentialInternal(withCredential: AnonymousCredential()))
    
        profileRequestShouldFail = true
        do {
            _ = try auth.loginWithCredentialInternal(
                withCredential: UserPasswordCredential.init(withUsername: "foo", withPassword: "bar")
            )
            XCTFail("expected subsequent login to fail because of profile request")
        } catch {
            // do nothing
        }
        
        XCTAssertFalse(auth.isLoggedIn)
        XCTAssertNil(auth.authInfo)
        XCTAssertNil(auth.user)
        
        // Scenario 3: User is logged in -> attempt to link to other identity -> initial link request succeeds
        //                               -> profile request fails -> error thrown -> original user is still logged in
        
        profileRequestShouldFail = false
        let userToBeLinked = try auth.loginWithCredentialInternal(withCredential: AnonymousCredential())
        
        profileRequestShouldFail = true
        do {
            _ = try auth.linkUserWithCredentialInternal(
                withUser: auth.user!,
                withCredential: UserPasswordCredential.init(withUsername: "hello", withPassword: "friend")
            )
            XCTFail("expected link request to fail because of profile request")
        } catch {
            // do nothing
        }
        
        XCTAssertTrue(auth.isLoggedIn)
        XCTAssertNotNil(auth.authInfo)
        XCTAssertEqual(userToBeLinked.id, auth.user!.id)
    }
}
