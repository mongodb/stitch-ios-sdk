import Foundation
import StitchCore
import StitchCoreAdminClient
import StitchCore_iOS
import MongoSwift
import XCTest

internal let defaultServerUrl = "http://localhost:9090"
internal let defaultTimeoutSeconds = 5.0

func buildAdminTestHarness(seedTestApp: Bool,
                           username: String = "unique_user@domain.com",
                           password: String = "password",
                           serverUrl: String = defaultServerUrl) -> TestHarness {
    let harness = TestHarness.init(username: username,
                                   password: password,
                                   serverUrl: serverUrl)
    harness.authenticate()
    if seedTestApp {
        _ = harness.createApp()
    }

    return harness
}

func buildClientTestHarness(username: String = "unique_user@domain.com",
                            password: String = "password",
                            serverUrl: String = defaultServerUrl,
                            _ completionHandler: @escaping (TestHarness) -> Void) {
    let harness = buildAdminTestHarness(seedTestApp: true,
                                        username: username,
                                        password: password,
                                        serverUrl: serverUrl)

    _ = harness.addDefaultUserpassProvider()
    _ = harness.createUser()
    harness.setupStitchClient {
        completionHandler(harness)
    }
}

//swiftlint:disable force_try
final class TestHarness {
    let adminClient: StitchAdminClient
    let serverUrl: String
    let username: String
    let password: String
    var testApp: AppResponse?
    var stitchAppClient: StitchAppClient!
    var userCredentials: (username: String, password: String)?
    var groupId: String?
    var user: UserResponse?

    lazy var apps: Apps = self.adminClient.apps(withGroupId: self.groupId!)

    var app: Apps.App {
        guard let testApp = self.testApp else {
            fatalError("App must be created first")
        }
        return self.apps.app(withAppId: testApp.id)
    }

    fileprivate init(username: String = "unique_user@domain.com",
                     password: String = "password",
                     serverUrl: String = defaultServerUrl) {
        self.username = username
        self.password = password
        self.serverUrl = serverUrl
        self.adminClient = StitchAdminClient.init(
            baseUrl: serverUrl,
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
        self.groupId = adminProfile.roles[0].groupId
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
            try! self.app.services.service(withId: serviceView.id).rules.create(data: creator)
        }
        return serviceView
    }

    func addProvider(withConfig config: ProviderConfigs) -> AuthProviderResponse {
        let resp = try! self.app.authProviders.create(data: config)
        try! self.app.authProviders.authProvider(providerId: resp.id).enable()
        return resp
    }

    func addDefaultUserpassProvider() -> AuthProviderResponse {
        return self.addProvider(withConfig: .userpass(emailConfirmationUrl: "http://emailConfirmURL.com",
                                                      resetPasswordUrl: "http://resetPasswordURL.com",
                                                      confirmEmailSubject: "email subject",
                                                      resetPasswordSubject: "password subject"))
    }

    func addDefaultAnonProvider() -> AuthProviderResponse {
        return self.addProvider(withConfig: .anon())
    }

    func enableDefaultApiKeyProvider() -> AuthProviderResponse {
        let resps = try! self.app.authProviders.list()
        let resp = resps.first { resp -> Bool in
            return resp.name == StitchProviderType.userAPIKey.name
        }
        try! self.app.authProviders.authProvider(providerId: resp!.id).enable()
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

    func setupStitchClient(_ completionHandler: @escaping () -> Void) {
        guard let userCredentials = self.userCredentials else {
            fatalError("must have user before setting up stitch client")
        }

        try! Stitch.initialize()

        let configBuilder = StitchAppClientConfigurationBuilder.init {
            $0.clientAppId = self.testApp?.clientAppId
            $0.baseURL = self.serverUrl
        }

        self.stitchAppClient = try! Stitch.initializeAppClient(withConfigBuilder: configBuilder)

        let userPassClient = self.stitchAppClient.auth.providerClient(
            forProvider: UserPasswordAuthProvider.clientSupplier
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
