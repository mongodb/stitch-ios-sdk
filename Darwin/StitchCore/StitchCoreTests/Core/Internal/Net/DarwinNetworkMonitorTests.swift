import Foundation
import XCTest
import StitchCoreSDK
@testable import StitchCore

class DarwinNetworkMonitorTests: XCTestCase, NetworkStateListener {
    var nm: DarwinNetworkMonitor!

    func onNetworkStateChanged() {
        print("isConnected: \(nm.isConnected)")
    }

    func testIsConnected() throws {
        nm = try DarwinNetworkMonitor.shared()
        nm.add(networkStateListener: self)

        let sem = DispatchSemaphore.init(value: 0)
        sem.wait()
    }
}
