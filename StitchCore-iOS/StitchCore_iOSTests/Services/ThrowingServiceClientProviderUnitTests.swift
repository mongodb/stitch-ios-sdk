import StitchCore_iOS
import StitchCore
import XCTest
import StitchCoreTestUtils_iOS

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

class ThrowingServiceClientProviderUnitTests: BaseStitchIntTestCocoaTouch {
    var appClient: StitchAppClient!
    
    override func setUp() {
        guard let client = try? Stitch.getDefaultAppClient() else {
            do {
                try Stitch.initialize()
                appClient = try? Stitch.initializeDefaultAppClient(
                    withConfigBuilder: StitchAppClientConfigurationBuilder.init({
                        $0.clientAppId = "placeholder-app-id"
                    }))
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
                forService: AnyThrowingServiceClientProvider<String>.init(
                    provider: TestThrowingServiceClientProvider()
                )
            )
        )
    }
}
