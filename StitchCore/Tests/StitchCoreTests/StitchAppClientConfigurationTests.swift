import XCTest
@testable import StitchCore

class StitchAppClientConfigurationBuilderTests: XCTestCase {
    private let clientAppId = "foo"
    private let localAppVersion = "bar"
    private let localAppName = "baz"
    private let baseURL = "qux"
    private let dataDirectory = URL.init(string: "foo/bar/baz/qux")!
    private let storage = MemoryStorage.init()
    private let transport = FoundationHTTPTransport.init()

    func testStitchAppClientConfigurationBuilderInit() throws {
        var builder = StitchAppClientConfigurationBuilder { _ in }

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchAppClientConfigurationError,
                           StitchAppClientConfigurationError.missingClientAppId)
        }

        builder.clientAppId = self.clientAppId
        builder.localAppVersion = self.localAppVersion
        builder.localAppName = self.localAppName

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingBaseURL)
        }

        builder.baseURL = self.baseURL

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingDataDirectory)
        }

        builder.dataDirectory = self.dataDirectory

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingStorage)
        }

        builder.storage = self.storage

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingTransport)
        }

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
