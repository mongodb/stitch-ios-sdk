import XCTest
import Foundation
import StitchCoreSDK
import StitchCoreAdminClient
import MongoSwift

open class BaseStitchIntTest: XCTestCase {
    lazy var adminClient: StitchAdminClient! = StitchAdminClient.init(baseURL: self.stitchBaseURL,
                                                                      transport: FoundationHTTPTransport())
    private var groupID: String!
    private var apps = [Apps.App]()
    private var initialized = false

    open var stitchBaseURL: String {
        fatalError("`stitchBaseURL` must be implemented")
    }

    open override func setUp() {
        // Verify stitch is up
        guard let url = URL(string: stitchBaseURL) else {
            XCTFail("\(stitchBaseURL) not valid URL")
            return
        }

        let defaultSession = URLSession(configuration: URLSessionConfiguration.default)

        var urlRequest = URLRequest(url: url)

        urlRequest.httpMethod = "GET"

        let sema = DispatchSemaphore(value: 0)

        var finalResponse: HTTPURLResponse?
        var error: Error?

        defaultSession.dataTask(with: urlRequest) { _, response, _ in
            defer { sema.signal() }
            finalResponse = response as? HTTPURLResponse
        }.resume()

        sema.wait()
        XCTAssertTrue(finalResponse?.statusCode == 200,
                      "Expected Stitch server to be available at '\(stitchBaseURL)'")

        do {
            _ = try adminClient.loginWithCredential(credential:
                UserPasswordCredential.init(
                    withUsername: "unique_user@domain.com",
                    withPassword: "password"
                )
            )

            groupID = try adminClient.adminProfile().roles.first?.groupID
            XCTAssertNotNil(groupID)
        } catch {
            XCTFail(error.localizedDescription)
        }
        initialized = true
    }

    open override func tearDown() {
        if !initialized {
            return
        }

        apps.forEach { try? $0.remove() }
        adminClient.logout()
    }

    public func createApp(
        withAppName appName: String = "test-\(ObjectId().description)"
    ) throws -> (AppResponse, Apps.App) {
        let appInfo = try adminClient.apps(withGroupID: groupID).create(name: appName)
        let app = adminClient.apps(withGroupID: groupID).app(withAppID: appInfo.id)
        apps.append(app)
        return (appInfo, app)
    }

    public func addProvider(toApp app: Apps.App,
                            withConfig config: ProviderConfigs) throws -> AuthProviderResponse {
        let resp = try app.authProviders.create(data: config)
        try app.authProviders.authProvider(providerID: resp.id).enable()
        return resp
    }

    public func addService(toApp app: Apps.App,
                           withType type: String,
                           withName name: String,
                           withConfig config: ServiceConfigs) throws -> (ServiceResponse, Apps.App.Services.Service) {
        let svcInfo = try app.services.create(data: config)
        let svc = app.services.service(withID: svcInfo.id)
        return (svcInfo, svc)
    }

    public func addRule(
        toService svc: Apps.App.Services.Service,
        withConfig config: RuleCreator) throws -> RuleResponse {
        return try svc.rules.create(data: config)
    }
}
