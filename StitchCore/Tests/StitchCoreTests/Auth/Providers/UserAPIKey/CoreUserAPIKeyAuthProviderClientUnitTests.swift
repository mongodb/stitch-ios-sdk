import Foundation
import MockUtils
import MongoSwift
import XCTest
import StitchCoreMocks
@testable import StitchCore

class CoreUserAPIKeyAuthProviderClientUnitTests: StitchXCTestCase {
    
    private func testClientCall(
        function: @escaping (CoreUserAPIKeyAuthProviderClient) throws -> Void,
        ignoresResponse: Bool,
        expectedRequest: StitchRequest
        ) throws {
        let clientAppId = "my_app-12345"
        
        let requestClient = MockStitchAuthRequestClient()
        let routes = StitchAppRoutes.init(clientAppId: clientAppId).authRoutes

        let client = CoreUserAPIKeyAuthProviderClient.init(
            withAuthRequestClient: requestClient,
            withAuthRoutes: routes
        )
        
        requestClient.doAuthenticatedRequestMock.doReturn(
            result: Response.init(statusCode: 204, headers: [:], body: nil),
            forArg: .any
        )
        
        // Because Swift is nil-safe, we always have to define values, and can't just generically return null like
        // we do in Java, so we need to return the correct types for each specific type of invocation.
        
        // Return an API key for create and single fetch routes
        requestClient.doAuthenticatedRequestWithDecodingMock.doReturn(
            result: UserAPIKey.init(id: ObjectId(), key: nil, name: "someKey", disabled: false),
            forArg: Matcher<StitchAuthRequest>.with(condition: { (req) -> Bool in
                return (req.method == .post && req.path.hasSuffix("/api_keys")) ||
                       (req.method == .get && req.path.range(of: "/api_keys/") != nil)
            })
        )
        
        // Return a list of API keys for the multiple fetch route
        requestClient.doAuthenticatedRequestWithDecodingMock.doReturn(
            result: [UserAPIKey.init(id: ObjectId(), key: nil, name: "someKey", disabled: false)],
            forArg: Matcher<StitchAuthRequest>.with(condition: { (req) -> Bool in
                return (req.method == .get && req.path.hasSuffix("/api_keys"))
            })
        )
        
        
        try function(client)
        if ignoresResponse {
            XCTAssertTrue(requestClient.doAuthenticatedRequestMock.verify(
                numberOfInvocations: 1,
                forArg: .any)
            )
            XCTAssertEqual(expectedRequest, requestClient.doAuthenticatedRequestMock.capturedInvocations[0])
            
            // should pass along errors
            requestClient.doAuthenticatedRequestMock.doThrow(
                error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
                forArg: .any
            )
        } else {
            XCTAssertTrue(requestClient.doAuthenticatedRequestWithDecodingMock.verify(
                numberOfInvocations: 1,
                forArg: .any
            ))

            XCTAssertEqual(expectedRequest,
                           requestClient.doAuthenticatedRequestWithDecodingMock.capturedInvocations[0])
            
            // should pass along errors
            requestClient.doAuthenticatedRequestWithDecodingMock.doThrow(
                error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
                forArg: .any
            )
        }
        
        do {
            try function(client)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testCreateApiKey() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        let apiKeyName = "api_key_name"
        
        let expectedRequestBuilder = StitchAuthDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.baseAuthRoute)/api_keys")
            .with(document: ["name": apiKeyName])
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            _ = try client.createApiKey(withName: apiKeyName)
        }, ignoresResponse: false, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testFetchApiKey() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        let keyToFetch = ObjectId()
        
        let expectedRequestBuilder = StitchAuthRequestBuilder()
            .with(method: .get)
            .with(path: "\(routes.baseAuthRoute)/api_keys/\(keyToFetch.description)")
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            _ = try client.fetchApiKey(withId: keyToFetch)
        }, ignoresResponse: false, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testFetchApiKeys() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        
        let expectedRequestBuilder = StitchAuthRequestBuilder()
            .with(method: .get)
            .with(path: "\(routes.baseAuthRoute)/api_keys")
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            _ = try client.fetchApiKeys()
        }, ignoresResponse: false, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testEnableApiKey() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        let keyToEnable = ObjectId()
        
        let expectedRequestBuilder = StitchAuthRequestBuilder()
            .with(method: .put)
            .with(path: "\(routes.baseAuthRoute)/api_keys/\(keyToEnable.description)/enable")
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            try client.enableApiKey(withId: keyToEnable)
        }, ignoresResponse: true, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testDisableApiKey() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        let keyToDisable = ObjectId()
        
        let expectedRequestBuilder = StitchAuthRequestBuilder()
            .with(method: .put)
            .with(path: "\(routes.baseAuthRoute)/api_keys/\(keyToDisable.description)/disable")
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            try client.disableApiKey(withId: keyToDisable)
        }, ignoresResponse: true, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testDeleteApiKey() throws {
        let routes = StitchAppRoutes.init(clientAppId: "my_app-12345").authRoutes
        let keyToDelete = ObjectId()
        
        let expectedRequestBuilder = StitchAuthRequestBuilder()
            .with(method: .delete)
            .with(path: "\(routes.baseAuthRoute)/api_keys/\(keyToDelete.description)")
            .withRefreshToken()
            .with(shouldRefreshOnFailure: false)
        
        try testClientCall(function: { client in
            try client.deleteApiKey(withId: keyToDelete)
        }, ignoresResponse: true, expectedRequest: expectedRequestBuilder.build())
    }
}
