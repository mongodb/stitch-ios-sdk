import XCTest
@testable import StitchCoreSDK

class StitchAppClientConfigurationUnitTests: XCTestCase {
    private let clientAppID = "foo"
    private let localAppVersion = "bar"
    private let localAppName = "baz"
    private let baseURL = "qux"
    private let dataDirectory = URL.init(string: "foo/bar/baz/qux")!
    private let storage = MemoryStorage.init()
    private let transport = FoundationHTTPTransport.init()
    private let defaultRequestTimeout: TimeInterval = testDefaultRequestTimeout

    func testStitchAppClientConfigurationBuilderInit() throws {
        let builder = StitchAppClientConfigurationBuilder()

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchAppClientConfigurationError,
                           StitchAppClientConfigurationError.missingClientAppID)
        }

        builder.with(clientAppID: self.clientAppID)
        builder.with(localAppVersion: self.localAppVersion)
        builder.with(localAppName: self.localAppName)

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingBaseURL)
        }

        builder.with(baseURL: self.baseURL)

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingDataDirectory)
        }

        builder.with(dataDirectory: self.dataDirectory)

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingStorage)
        }

        builder.with(storage: self.storage)

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingTransport)
        }

        builder.with(transport: self.transport)

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(error as? StitchClientConfigurationError,
                           StitchClientConfigurationError.missingDefaultRequestTimeout)
        }

        builder.with(defaultRequestTimeout: self.defaultRequestTimeout)

        let config = try builder.build()

        XCTAssertEqual(config.clientAppID, self.clientAppID)
        XCTAssertEqual(config.localAppVersion, self.localAppVersion)
        XCTAssertEqual(config.localAppName, self.localAppName)
        XCTAssertEqual(config.baseURL, self.baseURL)
        XCTAssert(config.storage is MemoryStorage)
        XCTAssert(config.transport is FoundationHTTPTransport)
        XCTAssertEqual(config.defaultRequestTimeout, self.defaultRequestTimeout)
    }
}
