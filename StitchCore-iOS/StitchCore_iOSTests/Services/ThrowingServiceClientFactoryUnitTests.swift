import StitchCore_iOS
import StitchCore
import XCTest
import StitchCoreTestUtils_iOS

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
        guard let client = try? Stitch.getDefaultAppClient() else {
            do {
                try Stitch.initialize()
                appClient = try? Stitch.initializeDefaultAppClient(
                    withConfigBuilder: StitchAppClientConfigurationBuilder()
                        .with(clientAppID: "placeholder-app-id")
                )
            } catch {
                XCTFail("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
            }

            return
        }

        self.appClient = client
    }

    func testThrowingServiceClient() throws {
        XCTAssertThrowsError(
            try appClient.serviceClient(
                forFactory: AnyThrowingServiceClientFactory<String>.init(
                    factory: TestThrowingServiceClientFactory()
                )
            )
        )
    }
}
