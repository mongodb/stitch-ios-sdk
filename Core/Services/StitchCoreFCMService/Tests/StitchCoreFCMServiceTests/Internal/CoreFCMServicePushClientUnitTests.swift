import Foundation
import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreSDKMocks
import StitchCoreFCMService

final class CoreFCMServicePushClientUnitTests: XCTestCase {
    func testRegister() throws {
        let coreClient = MockCoreStitchPushClient()
        let client = CoreFCMServicePushClient.init(pushClient: coreClient)
        
        let expectedToken = "wooHoo"
        let expectedInfo: Document = ["registrationToken": expectedToken]
        
        try client.register(withRegistrationToken: expectedToken)
        
        let infoArg = coreClient.registerInternalMock.capturedInvocations.last!
        
        XCTAssertEqual(expectedInfo, infoArg)
        
        // should pass along errors
        coreClient.registerInternalMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg: .any
        )
        do {
            try client.register(withRegistrationToken: expectedToken)
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testDeregister() throws {
        let coreClient = MockCoreStitchPushClient()
        let client = CoreFCMServicePushClient.init(pushClient: coreClient)

        try client.deregister()
        
        XCTAssertEqual(1, coreClient.deregisterInternalMock.invocations)
        
        // should pass along errors
        coreClient.deregisterInternalMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown)
        )
        do {
            try client.deregister()
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
