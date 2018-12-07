import Foundation
import XCTest
@testable import StitchCoreSDK

class StitchAppClientInfoUnitTests: XCTestCase, NetworkMonitor, AuthMonitor {
    var state: NetworkState = .connected

    var isLoggedIn: Bool = true

    var isConnected: Bool = true

    func add(networkStateDelegate delegate: NetworkStateDelegate) {

    }

    func remove(networkStateDelegate delegate: NetworkStateDelegate) {

    }

    private let clientAppID = "foo"
    private let dataDirectory = URL.init(string: "bar")!
    private let localAppName = "baz"
    private let localAppVersion = "qux"

    func testStitchAppClientInfoInit() {
        let stitchAppClientInfo = StitchAppClientInfo.init(clientAppID: self.clientAppID,
                                                           dataDirectory: self.dataDirectory,
                                                           localAppName: self.localAppName,
                                                           localAppVersion: self.localAppVersion,
                                                           networkMonitor: self,
                                                           authMonitor: self)

        XCTAssertEqual(stitchAppClientInfo.clientAppID, self.clientAppID)
        XCTAssertEqual(stitchAppClientInfo.dataDirectory, self.dataDirectory)
        XCTAssertEqual(stitchAppClientInfo.localAppName, self.localAppName)
        XCTAssertEqual(stitchAppClientInfo.localAppVersion, self.localAppVersion)
    }
}
