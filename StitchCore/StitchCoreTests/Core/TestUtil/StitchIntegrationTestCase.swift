import Foundation
import XCTest
import StitchCore

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
        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    override func tearDown() {
        let exp = expectation(description: "tore down integration tests")
        self.stitchAppClient.auth.logout { _ in
            self.harness.teardown()
            exp.fulfill()
        }

        wait(for: [exp], timeout: defaultTimeoutSeconds)
    }

    public func registerAndLogin(email: String = email,
                                 password: String = pass,
                                 _ completionHandler: @escaping (StitchUser) -> Void) {
        let emailPassClient = self.stitchAppClient.auth.providerClient(
            forFactory: UserPasswordAuthProvider.clientFactory
        )
        emailPassClient.register(withEmail: email, withPassword: password) { _ in
            let conf = try? self.harness.app.userRegistrations.sendConfirmation(toEmail: email)
            guard let safeConf = conf else { XCTFail("could not retrieve email confirmation token"); return }
            emailPassClient.confirmUser(withToken: safeConf.token,
                                        withTokenID: safeConf.tokenID
            ) { _ in
                self.stitchAppClient.auth.login(
                    withCredential: emailPassClient.credential(forUsername: email, forPassword: password)
                ) { user, _ in
                    guard let user = user else {
                        XCTFail("Failed to log in with username/password provider")
                        return
                    }
                    completionHandler(user)
                }
            }
        }
    }
}
