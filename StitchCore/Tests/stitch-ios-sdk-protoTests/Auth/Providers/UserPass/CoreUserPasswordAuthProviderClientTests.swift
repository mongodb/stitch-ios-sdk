import XCTest
import Swifter
@testable import StitchCore

private final class MockRoutes {
    private let authRoutes: StitchAuthRoutes
    private let providerName: String

    fileprivate init(withAuthRoutes authRoutes: StitchAuthRoutes,
                     withProviderName providerName: String) {
        self.authRoutes = authRoutes
        self.providerName = providerName
    }

    private func extensionRoute(forPath path: String) -> String{
        return "\(authRoutes.authProviderLoginRoute(withProviderName: providerName))/\(path)"
    }

    fileprivate lazy var registerWithEmailRoute = self.extensionRoute(forPath: "register")

    fileprivate lazy var confirmUserRoute = self.extensionRoute(forPath: "confirm")

    fileprivate lazy var resendConfirmationEmailRoute = self.extensionRoute(forPath: "confirm/send")

    fileprivate lazy var resetPasswordRoute = self.extensionRoute(forPath: "reset")

    fileprivate lazy var sendResetPasswordEmailRoute = self.extensionRoute(forPath: "reset/send")
}

class CoreUserPasswordAuthProviderClientTests: StitchXCTestCase {
    let routes = StitchAppRoutes.init(clientAppId: "")

    let providerName = "local-userpass"

    var core: CoreUserPasswordAuthProviderClient!
    
    private lazy var mockRoutes = MockRoutes.init(withAuthRoutes: routes.authRoutes,
                                                  withProviderName: providerName)

    let username = "username@10gen.com", password = "password"

    override func setUp() {
        server[mockRoutes.registerWithEmailRoute] = { _ in
            return .ok(.text(""))
        }
        server[mockRoutes.confirmUserRoute] = { _ in
            return .ok(.text(""))
        }
        server[mockRoutes.resendConfirmationEmailRoute] = { _ in
            return .ok(.text(""))
        }

        super.setUp()

        core = CoreUserPasswordAuthProviderClient.init(
            withProviderName: self.providerName,
            withRequestClient: StitchRequestClientImpl.init(baseURL: self.baseURL,
                                                        transport: FoundationHTTPTransport()),
            withRoutes: routes.authRoutes
        )
    }

    func testCredential() throws {
        let credential = core.credential(forUsername: self.username,
                                         forPassword: self.password)
        XCTAssertEqual(credential.providerName, self.providerName)
        print(credential.material)
        XCTAssertEqual(credential.material["username"] as? String,
                       self.username)
        XCTAssertEqual(credential.material["password"] as? String,
                       self.password)
        XCTAssertEqual(credential.providerCapabilities.reusesExistingSession, false)
    }

    func testRegister() throws {
        let response = try core.register(withEmail: username,
                                         withPassword: password)

        XCTAssertEqual(response.statusCode, 200)
    }

    func testConfirmUser() throws {
        let response = try core.confirmUser(withToken: "token",
                                            withTokenId: "tokenId")

        XCTAssertEqual(response.statusCode, 200)
    }

    func testResendConfirmation() throws {
        let response = try core.resendConfirmation(toEmail: username)

        XCTAssertEqual(response.statusCode, 200)
    }
}
