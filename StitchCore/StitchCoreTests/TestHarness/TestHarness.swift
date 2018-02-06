//
//  TestHarness.swift
//  StitchCoreTests
//
//  Created by Jason Flax on 2/1/18.
//  Copyright © 2018 MongoDB. All rights reserved.
//

import Foundation
@testable import StitchCore
import PromiseKit
import ExtendedJson

internal let defaultServerUrl = "http://localhost:9090"

func buildAdminTestHarness(seedTestApp: Bool,
                           username: String = "unique_user@domain.com",
                           password: String = "password",
                           serverUrl: String = defaultServerUrl) -> Promise<TestHarness> {
    var harness: TestHarness!
    return TestHarnessFactory.create(username: username,
                                     password: password,
                                     serverUrl: serverUrl)
    .then { (testHarness: TestHarness) -> Promise<Void> in
        harness = testHarness
        return harness.authenticate()
    }.then { (_) -> Promise<Void> in
        if (seedTestApp) {
            return harness.createApp().asVoid()
        }

        return Promise().asVoid()
    }.flatMap { _ in return harness! }
}

func buildClientTestHarness(username: String = "unique_user@domain.com",
                            password: String = "password",
                            serverUrl: String = defaultServerUrl) -> Promise<TestHarness> {
    var harness: TestHarness!
    return buildAdminTestHarness(seedTestApp: true,
                                 username: username,
                                 password: password,
                                 serverUrl: serverUrl).then { (testHarness: TestHarness) -> Promise<Void> in
        harness = testHarness
        return harness.addDefaultUserpassConfig().asVoid()
    }.then { _ in
        return harness.createUser()
    }.then { _ in
        return harness.setupStitchClient(shouldConfigureUserAuth: false)
    }.flatMap { harness }
}

private class TestHarnessFactory {
    static func create(username: String = "unique_user@domain.com",
                       password: String = "password",
                       serverUrl: String = defaultServerUrl) -> Promise<TestHarness> {
        let testHarness = TestHarness(username: username, password: password, serverUrl: serverUrl)
        return testHarness.initPromise.flatMap { testHarness }
    }
}

final class TestHarness {
    var adminClient: StitchAdminClient!
    let initPromise: Promise<Void>
    let serverUrl: String
    let username: String
    let password: String
    var testApp: AppView?
    var stitchClient: StitchClient?
    var userCredentials: (username: String, password: String)?
    var groupId: String?
    var user: UserView?

    lazy var apps: AppsEndpoint = self.adminClient.apps(withGroupId: self.groupId!)

    var app: AppEndpoint {
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
        self.initPromise = Promise()
        initPromise.then {
            StitchAdminClientFactory.create(baseUrl: self.serverUrl)
        }.done {
            self.adminClient = $0
        }.cauterize()
    }

    func teardown() -> Promise<Void> {
        return self.app.remove().asVoid()
    }

    func authenticate() -> Promise<Void> {
        return self.adminClient.authenticate(
            provider: EmailPasswordAuthProvider.init(username: self.username,
                                                     password: self.password)
        ).then { (_) -> Promise<UserProfile> in
            return self.adminClient.fetchUserProfile()
        }.done { (userProfile: UserProfile) in
            self.groupId = userProfile.roles!.first?.groupId
        }
    }

    func createApp(testAppName: String = "test-\(ObjectId.init().hexString)") -> Promise<AppView> {
        return self.apps.create(name: testAppName).flatMap {
            self.testApp = $0
            return $0
        }
    }

    func createUser(email: String = "test_user@domain.com",
                    password: String = "password") -> Promise<UserView> {
        self.userCredentials = (username: email, password: password)
        return self.app.users.create(data: UserCreator.init(email: email, password: password)).flatMap {
            self.user = $0
            return self.user
        }
    }

    func add(serviceConfig: ServiceConfigs, withRules rules: Rule...) -> Promise<ServiceView> {
        return self.app.services.create(data: serviceConfig).then { view in
            return when(resolved: rules.map {
                return self.app.services.service(withId: view.id).rules.create(data: $0)
            }).flatMap { _ in view }
        }
    }
    
    func add(providerConfig: ProviderConfigs) -> Promise<AuthProviderView> {
        return self.app.authProviders.create(data: providerConfig)
    }

    func addDefaultUserpassConfig() -> Promise<AuthProviderView> {
        return self.add(providerConfig: .userpass(emailConfirmationUrl: "http://emailConfirmURL.com",
                                                  resetPasswordUrl: "http://resetPasswordURL.com",
                                                  confirmEmailSubject: "email subject",
                                                  resetPasswordSubject: "password subject"))
    }

    func addDefaultAnonConfig() -> Promise<AuthProviderView> {
        return self.add(providerConfig: .anon())
    }

    func addDefaultCustomTokenConfig() -> Promise<AuthProviderView> {
        return self.add(providerConfig: .custom(signingKey: "abcdefghijklmnopqrstuvwxyz1234567890"))
    }

    func setupStitchClient(shouldConfigureUserAuth: Bool = true) -> Promise<Void> {
        guard let userCredentials = self.userCredentials else {
            fatalError("must have user before setting up stitch client")
        }
        
        return StitchClientFactory.create(
                appId: self.testApp!.clientAppId,
                baseUrl: self.serverUrl
        ).then { (stitchClient: StitchClient) -> Promise<Void> in
            self.stitchClient = stitchClient
            return self.stitchClient!.login(
                withProvider: EmailPasswordAuthProvider.init(username: userCredentials.username,
                                                             password: userCredentials.password)).asVoid()
        }.then {
            self.addDefaultAnonConfig()
        }.asVoid()
    }
}
