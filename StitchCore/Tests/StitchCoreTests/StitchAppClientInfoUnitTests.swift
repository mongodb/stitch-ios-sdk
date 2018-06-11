import Foundation
import XCTest
@testable import StitchCore

class StitchAppClientInfoUnitTests: XCTestCase {
    private let clientAppId = "foo"
    private let dataDirectory = URL.init(string: "bar")!
    private let localAppName = "baz"
    private let localAppVersion = "qux"

    func testStitchAppClientInfoInit() {
        let stitchAppClientInfo = StitchAppClientInfo.init(clientAppId: self.clientAppId,
                                                           dataDirectory: self.dataDirectory,
                                                           localAppName: self.localAppName,
                                                           localAppVersion: self.localAppVersion)

        XCTAssertEqual(stitchAppClientInfo.clientAppId, self.clientAppId)
        XCTAssertEqual(stitchAppClientInfo.dataDirectory, self.dataDirectory)
        XCTAssertEqual(stitchAppClientInfo.localAppName, self.localAppName)
        XCTAssertEqual(stitchAppClientInfo.localAppVersion, self.localAppVersion)
    }
}
