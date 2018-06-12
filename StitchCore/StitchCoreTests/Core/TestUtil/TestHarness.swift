import Foundation
import StitchCoreSDK
import StitchCoreAdminClient
import StitchCore
import MongoSwift
import XCTest

internal let defaultServerURL = "http://localhost:9090"
internal let defaultTimeoutSeconds = 5.0

func buildAdminTestHarness(seedTestApp: Bool,
                           username: String = "unique_user@domain.com",
                           password: String = "password",
                           serverURL: String = defaultServerURL) -> TestHarness {
    let harness = TestHarness.init(username: username,
                                   password: password,
                                   serverURL: serverURL)
    harness.authenticate()
    if seedTestApp {
        _ = harness.createApp()
    }

    return harness
}

func buildClientTestHarness(username: String = "unique_user@domain.com",
                            password: String = "password",
                            serverURL: String = defaultServerURL,
                            _ completionHandler: @escaping (TestHarness) -> Void) {
    let harness = buildAdminTestHarness(seedTestApp: true,
                                        username: username,
                                        password: password,
                                        serverURL: serverURL)

    _ = harness.addDefaultUserpassProvider()
    _ = harness.createUser()
    harness.setupStitchClient {
        completionHandler(harness)
    }
}

//swiftlint:disable force_try
final class TestHarness {
    let adminClient: StitchAdminClient
    let serverURL: String
    let username: String
    let password: String
    var testApp: AppResponse?
    var stitchAppClient: StitchAppClient!
    var userCredentials: (username: String, password: String)?
    var groupID: String?
    var user: UserResponse?

    lazy var apps: Apps = self.adminClient.apps(withGroupID: self.groupID!)

    var app: Apps.App {
        guard let testApp = self.testApp else {
            fatalError("App must be created first")
        }
        return self.apps.app(withAppID: testApp.id)
    }

    fileprivate init(username: String = "unique_user@domain.com",
                     password: String = "password",
                     serverURL: String = defaultServerURL) {
        self.username = username
        self.password = password
        self.serverURL = serverURL
        self.adminClient = StitchAdminClient.init(
            baseURL: serverURL,
            transport: FoundationHTTPTransport.init()
        )!
    }

    func teardown() {
        try! self.app.remove()
    }

    func authenticate() {
        _ = try! self.adminClient.loginWithCredential(
            credential: UserPasswordCredential(withProviderName: StitchProviderType.userPassword.name,
                                               withUsername: self.username,
                                               withPassword: self.password)
        )

        let adminProfile = try! self.adminClient.adminProfile()
        self.groupID = adminProfile.roles[0].groupID
    }

    func createApp(testAppName: String = "test-\(ObjectId().description)") -> AppResponse {
        self.testApp = try! self.apps.create(name: testAppName)
        return self.testApp!
    }

    func createUser(email: String = "test_user@domain.com",
                    password: String = "password") -> UserResponse {

        self.userCredentials = (username: email, password: password)
        self.user = try! self.app.users.create(
            data: UserCreator.init(email: email, password: password)
        )
        return self.user!
    }

    func add(serviceConfig: ServiceConfigs, withRules rules: RuleCreator...) -> ServiceResponse {

        let serviceView = try! self.app.services.create(data: serviceConfig)
        _ = rules.map { creator in
            try! self.app.services.service(withID: serviceView.id).rules.create(data: creator)
        }
        return serviceView
    }

    func addProvider(withConfig config: ProviderConfigs) -> AuthProviderResponse {
        let resp = try! self.app.authProviders.create(data: config)
        try! self.app.authProviders.authProvider(providerID: resp.id).enable()
        return resp
    }

    func addDefaultUserpassProvider() -> AuthProviderResponse {
        return self.addProvider(withConfig: .userpass(emailConfirmationURL: "http://emailConfirmUrl.com",
                                                      resetPasswordURL: "http://resetPasswordUrl.com",
                                                      confirmEmailSubject: "email subject",
                                                      resetPasswordSubject: "password subject"))
    }

    func addDefaultAnonProvider() -> AuthProviderResponse {
        return self.addProvider(withConfig: .anon())
    }

    func enableDefaultAPIKeyProvider() -> AuthProviderResponse {
        let resps = try! self.app.authProviders.list()
        let resp = resps.first { resp -> Bool in
            return resp.name == StitchProviderType.userAPIKey.name
        }
        try! self.app.authProviders.authProvider(providerID: resp!.id).enable()
        return resp!
    }

    func addDefaultCustomTokenProvider() -> AuthProviderResponse {
        return self.addProvider(withConfig: .custom(
            signingKey: "abcdefghijklmnopqrstuvwxyz1234567890",
            metadataFields: [ProviderConfigs.MetadataField.init(required: true, name: "email"),
                             ProviderConfigs.MetadataField.init(required: true, name: "name"),
                             ProviderConfigs.MetadataField.init(required: true, name: "picture_url")]
            )
        )
    }

    func addTestFunction() -> FunctionResponse {
        return try! self.app.functions.create(data: FunctionCreator.init(
            name: "testFunction",
            source: "exports = function(intArg, stringArg) { " +
                    "return { intValue: intArg, stringValue: stringArg} " +
                    "}",
            canEvaluate: nil,
            isPrivate: false)
        )
    }

    func addTestFunctionsRawValues() -> [FunctionResponse] {
        let rawIntFunction = try! self.app.functions.create(data: FunctionCreator.init(
            name: "testFunctionRawInt",
            source: "exports = function() { " +
                "return 42" +
            "}",
            canEvaluate: nil,
            isPrivate: false)
        )

        let rawStringFunction = try! self.app.functions.create(data: FunctionCreator.init(
            name: "testFunctionRawString",
            source: "exports = function() { " +
                "return \"hello world!\"" +
            "}",
            canEvaluate: nil,
            isPrivate: false)
        )

        let rawArrayFunction = try! self.app.functions.create(data: FunctionCreator.init(
            name: "testFunctionRawArray",
            source: "exports = function() { " +
                "return [1, 2, 3]" +
            "}",
            canEvaluate: nil,
            isPrivate: false)
        )

        let rawHeterogenousArrayFunction = try! self.app.functions.create(data: FunctionCreator.init(
            name: "testFunctionRawHeterogenousArray",
            source: "exports = function() { " +
                "return [1, \"two\", 3]" +
            "}",
            canEvaluate: nil,
            isPrivate: false)
        )

        return [rawIntFunction, rawStringFunction, rawArrayFunction, rawHeterogenousArrayFunction]
    }

    func setupStitchClient(_ completionHandler: @escaping () -> Void) {
        guard let userCredentials = self.userCredentials else {
            fatalError("must have user before setting up stitch client")
        }

        try! Stitch.initialize()

        let configBuilder = StitchAppClientConfigurationBuilder()
            .with(clientAppID: self.testApp!.clientAppID)
            .with(baseURL: self.serverURL)

        self.stitchAppClient = try! Stitch.initializeAppClient(withConfigBuilder: configBuilder)

        let userPassClient = self.stitchAppClient.auth.providerClient(
            forFactory: UserPasswordAuthProvider.clientFactory
        )

        self.stitchAppClient.auth.login(withCredential: userPassClient.credential(
            forUsername: userCredentials.username,
            forPassword: userCredentials.password
            ), { _, _ in
                _ = self.addDefaultAnonProvider()
                completionHandler()
        })
    }
}
//swiftlint:enable force_try
