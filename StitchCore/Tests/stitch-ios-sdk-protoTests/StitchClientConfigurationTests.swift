import XCTest
@testable import StitchCore

class StitchClientConfigurationTests: XCTestCase {
    private let baseURL = "qux"
    private let storage = MemoryStorage.init()
    private let transport = FoundationHTTPTransport.init()

    func testStitchClientConfigurationBuilderImplInit() throws {
        var builder = StitchClientConfigurationBuilderImpl { _ in }

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

        XCTAssertEqual(config.baseURL, self.baseURL)
        XCTAssert(config.storage is MemoryStorage)
        XCTAssert(config.transport is FoundationHTTPTransport)
    }
}
