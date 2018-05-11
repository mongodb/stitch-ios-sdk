import StitchCore_iOS
import StitchCore
import XCTest

private final class TestThrowingServiceClientProvider: ThrowingServiceClientProvider {
    typealias ClientType = String

    func client(forService service: StitchService,
                withClientInfo clientInfo: StitchAppClientInfo) throws -> TestThrowingServiceClientProvider.ClientType {
        throw StitchError.serviceError(
            withMessage: "test-message",
            withServiceErrorCode: StitchServiceErrorCode.unknown
        )
    }
}

class ThrowingServiceClientProviderUnitTests: XCTestCase {
    override func setUp() {
        do {
            try Stitch.initialize()
            _ = try Stitch.initializeDefaultAppClient(
                withConfigBuilder: StitchAppClientConfigurationBuilder.init({
                    $0.clientAppId = "placeholder-app-id"
                }))
        } catch {
            XCTFail("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
        }
    }

    func testThrowingServiceClient() throws {
        let client = try Stitch.getDefaultAppClient()

        XCTAssertThrowsError(
            try client.serviceClient(
                forService: AnyThrowingServiceClientProvider<String>.init(
                    provider: TestThrowingServiceClientProvider()
                )
            )
        )
    }
}
