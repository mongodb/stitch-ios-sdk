import XCTest
@testable import StitchCore

class StitchAppClientConfigurationBuilderTests: XCTestCase {
    private let clientAppId = "foo"
    private let localAppVersion = "bar"
    private let localAppName = "baz"
    private let baseURL = "qux"
    private let storage = MemoryStorage.init()
    private let transport = FoundationHTTPTransport.init()

    func testStitchAppClientConfigurationBuilderInit() throws {
        var builder = StitchAppClientConfigurationBuilder { _ in }

        XCTAssertThrowsError(try builder.build(),
                             StitchAppClientConfigurationError.missingClientAppId.localizedDescription)

        builder.clientAppId = self.clientAppId
        builder.localAppVersion = self.localAppVersion
        builder.localAppName = self.localAppName

        XCTAssertThrowsError(try builder.build(),
                             StitchClientConfigurationError.missingBaseURL.localizedDescription)

        builder.baseURL = self.baseURL

        XCTAssertThrowsError(try builder.build(),
                             StitchClientConfigurationError.missingStorage.localizedDescription)

        builder.storage = self.storage

        XCTAssertThrowsError(try builder.build(),
                             StitchClientConfigurationError.missingTransport.localizedDescription)

        builder.transport = self.transport

        let config = try builder.build()

        XCTAssertEqual(config.clientAppId, self.clientAppId)
        XCTAssertEqual(config.localAppVersion, self.localAppVersion)
        XCTAssertEqual(config.localAppName, self.localAppName)
        XCTAssertEqual(config.baseURL, self.baseURL)
        XCTAssert(config.storage is MemoryStorage)
        XCTAssert(config.transport is FoundationHTTPTransport)
    }
}
