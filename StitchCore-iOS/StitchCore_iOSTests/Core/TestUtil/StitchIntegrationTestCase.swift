import Foundation
import XCTest
import StitchCore_iOS

internal class StitchIntegrationTestCase: XCTestCase {
    internal var harness: TestHarness!
    internal var stitchAppClient: StitchAppClient!

    internal static let email = "stitch@10gen.com"
    internal static let pass = "stitchuser"

    override func setUp() {
        let exp = expectation(description: "set up integration tests")
        buildClientTestHarness { harness in
            self.harness = harness
            self.stitchAppClient = harness.stitchAppClient
            self.stitchAppClient.auth.logout { _ in
                exp.fulfill()
            }

        }
        wait(for: [exp], timeout: 10.0)
    }

    override func tearDown() {
        let exp = expectation(description: "tore down integration tests")
        self.stitchAppClient.auth.logout { _ in
            self.harness.teardown()
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10.0)
    }

}
