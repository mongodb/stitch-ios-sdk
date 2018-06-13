import XCTest
@testable import StitchCoreSDK
import StitchCoreSDKMocks

class CoreUserPasswordAuthProviderClientUnitTests: StitchXCTestCase {
    
    private func testClientCall(function: @escaping (CoreUserPasswordAuthProviderClient) throws -> Void,
                                expectedRequest: StitchRequest) throws {
        let clientAppID = "my_app-12345"
        let providerName = "userPassProvider"
        
        let requestClient = MockStitchRequestClient()
        let routes = StitchAppRoutes.init(clientAppID: clientAppID).authRoutes
        let client = CoreUserPasswordAuthProviderClient.init(
            withProviderName: providerName,
            withRequestClient: requestClient,
            withAuthRoutes: routes
        )
        
        requestClient.doRequestMock.doReturn(
            result: Response.init(statusCode: 204, headers: [:], body: nil),
            forArg: .any
        )
        
        try function(client)
        XCTAssertTrue(requestClient.doRequestMock.verify(numberOfInvocations: 1, forArg: .any))
        
        XCTAssertEqual(expectedRequest, requestClient.doRequestMock.capturedInvocations[0])
        
        // should pass along errors
        requestClient.doRequestMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg: .any
        )
        do {
            try function(client)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testRegister() throws {
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let username = "username@10gen.com"
        let password = "password"
        
        let expectedRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.authProviderRoute(withProviderName: "userPassProvider"))/register")
            .with(document: ["email": username, "password": password])
        
        try testClientCall(function: { client in
            _ = try client.register(withEmail: username, withPassword: password)
        }, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testConfirmUser() throws {
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let token = "some"
        let tokenID = "thing"
        
        let expectedRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.authProviderRoute(withProviderName: "userPassProvider"))/confirm")
            .with(document: ["token": token, "tokenId": tokenID])
        
        try testClientCall(function: { client in
            _ = try client.confirmUser(withToken: token, withTokenID: tokenID)
        }, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testResendConfirmation() throws {
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let email = "username@10gen.com"
        
        let expectedRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.authProviderRoute(withProviderName: "userPassProvider"))/confirm/send")
            .with(document: ["email": email])
        
        try testClientCall(function: { client in
            _ = try client.resendConfirmation(toEmail: email)
        }, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testSendResetPasswordEmail() throws {
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        let email = "username@10gen.com"
        
        let expectedRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.authProviderRoute(withProviderName: "userPassProvider"))/reset/send")
            .with(document: ["email": email])
        
        try testClientCall(function: { client in
            _ = try client.sendResetPasswordEmail(toEmail: email)
        }, expectedRequest: expectedRequestBuilder.build())
    }
    
    func testResetPassword() throws {
        let routes = StitchAppRoutes.init(clientAppID: "my_app-12345").authRoutes
        
        let token = "some"
        let tokenID = "thing"
        let newPassword = "correcthorsebatterystaple"
        
        let expectedRequestBuilder = StitchDocRequestBuilder()
            .with(method: .post)
            .with(path: "\(routes.authProviderRoute(withProviderName: "userPassProvider"))/reset")
            .with(document: ["token": token, "tokenId": tokenID, "password": newPassword])
        
        try testClientCall(function: { client in
            _ = try client.reset(password: newPassword, withToken: token, withTokenID: tokenID)
        }, expectedRequest: expectedRequestBuilder.build())
    }
}
