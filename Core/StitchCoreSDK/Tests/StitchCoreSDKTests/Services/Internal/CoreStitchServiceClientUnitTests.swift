import XCTest
import MongoSwift
@testable import StitchCoreSDK
import StitchCoreSDKMocks

private let appRoutes = StitchAppRoutes.init(clientAppID: "")
private let mockServiceName = "mockService"
private let mockFunctionName = "mockFunction"
private let mockArgs = [0, 1, 2]
private let expectedDoc: Document = [
    "name": mockFunctionName,
    "service": mockServiceName,
    "arguments": mockArgs
]

class CoreStitchServiceClientUnitTests: XCTestCase {
    
    func testCallFunction() throws {
        let serviceName = "svc1"
        let routes = StitchAppRoutes.init(clientAppID: "foo").serviceRoutes
        let requestClient = MockStitchAuthRequestClient()
        
        let coreStitchService = CoreStitchServiceClientImpl.init(
            requestClient: requestClient,
            routes: routes,
            serviceName: serviceName
        )
        
        requestClient.doAuthenticatedRequestWithDecodingMock.doReturn(result: 42, forArg: .any)
        
        let funcName = "myFunc"
        let args = [1, 2, 3]
        let expectedRequestDoc: Document = ["name": funcName, "arguments": args, "service": serviceName]

        XCTAssertEqual(42, try coreStitchService.callFunction(withName: funcName, withArgs: args))
        
        let functionCallRequest =
            requestClient.doAuthenticatedRequestWithDecodingMock.capturedInvocations[0] as? StitchAuthDocRequest
        
        XCTAssertEqual(functionCallRequest?.method, Method.post)
        XCTAssertEqual(functionCallRequest?.path, routes.functionCallRoute)
        XCTAssertEqual(functionCallRequest?.document, expectedRequestDoc)
    }
}
