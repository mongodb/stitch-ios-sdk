import XCTest
@testable import StitchCore

class StitchTests: XCTestCase {

    override func setUp() {
        do {
            try Stitch.initialize()
            _ = try Stitch.initializeDefaultAppClient(
                withConfigBuilder: StitchAppClientConfigurationBuilder()
                    .with(clientAppID: "placeholder-app-id")
                )
        } catch {
            XCTFail("Failed to initialize MongoDB Stitch iOS SDK: \(error.localizedDescription)")
        }
    }

    func testDataDirectoryInitialization() {
        let client: StitchAppClient! = Stitch.defaultAppClient

        guard let clientImpl = client as? StitchAppClientImpl else {
            XCTFail("App client is not a StitchAppClientImpl")
            return
        }

        // Check that the default data directory configured by the SDK exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: clientImpl.info.dataDirectory.path))
    }
}
