import StitchCore
import StitchCoreSDK
import XCTest
import StitchDarwinCoreTestUtils

private final class TestThrowingServiceClientFactory: ThrowingServiceClientFactory {
    typealias ClientType = String

    func client(withServiceClient service: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> TestThrowingServiceClientFactory.ClientType {
        throw StitchError.serviceError(
            withMessage: "test-message",
            withServiceErrorCode: StitchServiceErrorCode.unknown
        )
    }
}

class ThrowingServiceClientFactoryUnitTests: BaseStitchIntTestCocoaTouch {
    var appClient: StitchAppClient!

    override func setUp() {
        guard let client = Stitch.defaultAppClient else {
            appClient = try? Stitch.initializeDefaultAppClient(
                withClientAppID: "placeholder-app-id"
            )
            return
        }

        self.appClient = client
    }

    func testThrowingServiceClient() throws {
        XCTAssertThrowsError(
            try appClient.serviceClient(
                fromFactory: AnyThrowingServiceClientFactory<String>.init(
                    factory: TestThrowingServiceClientFactory()
                )
            )
        )
    }
}
