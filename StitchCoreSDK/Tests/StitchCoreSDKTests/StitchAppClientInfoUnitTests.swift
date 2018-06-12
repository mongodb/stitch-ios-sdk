import Foundation
import XCTest
@testable import StitchCoreSDK

class StitchAppClientInfoUnitTests: XCTestCase {
    private let clientAppID = "foo"
    private let dataDirectory = URL.init(string: "bar")!
    private let localAppName = "baz"
    private let localAppVersion = "qux"

    func testStitchAppClientInfoInit() {
        let stitchAppClientInfo = StitchAppClientInfo.init(clientAppID: self.clientAppID,
                                                           dataDirectory: self.dataDirectory,
                                                           localAppName: self.localAppName,
                                                           localAppVersion: self.localAppVersion)

        XCTAssertEqual(stitchAppClientInfo.clientAppID, self.clientAppID)
        XCTAssertEqual(stitchAppClientInfo.dataDirectory, self.dataDirectory)
        XCTAssertEqual(stitchAppClientInfo.localAppName, self.localAppName)
        XCTAssertEqual(stitchAppClientInfo.localAppVersion, self.localAppVersion)
    }
}
