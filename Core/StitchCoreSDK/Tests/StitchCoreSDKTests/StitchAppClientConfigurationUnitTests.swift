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

        builder.with(localAppVersion: self.localAppVersion)
        builder.with(localAppName: self.localAppName)

        builder.with(baseURL: self.baseURL)
        builder.with(dataDirectory: self.dataDirectory)
        builder.with(storage: self.storage)
        builder.with(transport: self.transport)

        builder.with(defaultRequestTimeout: self.defaultRequestTimeout)

        let config = builder.build()

        XCTAssertEqual(config.localAppVersion, self.localAppVersion)
        XCTAssertEqual(config.localAppName, self.localAppName)
        XCTAssertEqual(config.baseURL, self.baseURL)
        XCTAssert(config.storage is MemoryStorage)
        XCTAssert(config.transport is FoundationHTTPTransport)
        XCTAssertEqual(config.defaultRequestTimeout, self.defaultRequestTimeout)
    }
}
