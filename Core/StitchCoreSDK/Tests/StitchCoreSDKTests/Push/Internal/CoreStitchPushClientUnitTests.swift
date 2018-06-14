import Foundation
import XCTest
import MongoSwift
@testable import StitchCoreSDK
import StitchCoreSDKMocks

public class CoreStitchPushClientUnitTests: XCTestCase {
    
    func testRegister() throws {
        let serviceName = "svc1"
        let routes = StitchPushRoutes.init(clientAppID: "foo")
        let requestClient = MockStitchAuthRequestClient()
        
        let client: CoreStitchPushClient = CoreStitchPushClientImpl.init(
            requestClient: requestClient,
            routes: routes,
            serviceName: serviceName
        )
        
        requestClient.doAuthenticatedRequestMock.doReturn(
            result: Response.init(statusCode: 200, headers: [:], body: nil),
            forArg: .any
        )
        
        let expectedInfo: Document = ["woo": "hoo"]
        
        try client.registerInternal(withRegistrationInfo: expectedInfo)
        
        let docArgument = requestClient.doAuthenticatedRequestMock.capturedInvocations.last!
        
        guard let fullArg = docArgument as? StitchAuthDocRequest else {
            XCTFail("argument was not passed as a StitchAuthDocRequest")
            return
        }
        
        XCTAssertEqual(.put, fullArg.method)
        XCTAssertEqual(routes.registrationRoute(forServiceName: serviceName), fullArg.path)
        XCTAssertEqual(expectedInfo, fullArg.document)
        
        // should pass along errors
        requestClient.doAuthenticatedRequestMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg: .any
        )
        do {
            try client.registerInternal(withRegistrationInfo: expectedInfo)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testDeregister() throws {
        let serviceName = "svc1"
        let routes = StitchPushRoutes.init(clientAppID: "foo")
        let requestClient = MockStitchAuthRequestClient()
        
        let client: CoreStitchPushClient = CoreStitchPushClientImpl.init(
            requestClient: requestClient,
            routes: routes,
            serviceName: serviceName
        )
        
        requestClient.doAuthenticatedRequestMock.doReturn(
            result: Response.init(statusCode: 200, headers: [:], body: nil),
            forArg: .any
        )
        
        try client.deregisterInternal()
        
        let argument = requestClient.doAuthenticatedRequestMock.capturedInvocations.last!
        
        XCTAssertEqual(.delete, argument.method)
        XCTAssertEqual(routes.registrationRoute(forServiceName: serviceName), argument.path)
        
        // should pass along errors
        requestClient.doAuthenticatedRequestMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg: .any
        )
        do {
            try client.deregisterInternal()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}

