import Foundation
import XCTest
import StitchCoreTestUtils
import StitchDarwinCoreTestUtils
import StitchCoreAdminClient
import MongoSwift
import StitchCore

class StitchCustomUserDataIntTests: BaseStitchIntTestCocoaTouch {
    internal static let email = "stitch@10gen.com"
    internal static let pass = "stitchuser"

    private let mongodbUriProp = "test.stitch.mongodbURI"

    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))

    private lazy var mongodbUri: String = pList?[mongodbUriProp] as? String ?? "mongodb://localhost:26000"

    private let dbName = ObjectId().hex
    private let collName = ObjectId().hex

    private var client: StitchAppClient!
    private var app: Apps.App!
    private var svcId: String!

    public func registerAndLogin(email: String = email,
                                 password: String = pass,
                                 _ completionHandler: @escaping (StitchUser) -> Void) throws {
        let emailPassClient = self.client.auth.providerClient(
            fromFactory: userPasswordClientFactory
        )
        emailPassClient.register(withEmail: email, withPassword: password) { _ in
            let conf = try? self.app.userRegistrations.sendConfirmation(toEmail: email)
            guard let safeConf = conf else { XCTFail("could not retrieve email confirmation token"); return }
            emailPassClient.confirmUser(withToken: safeConf.token,
                                        withTokenID: safeConf.tokenID
            ) { _ in
                self.client.auth.login(
                    withCredential: UserPasswordCredential(withUsername: email, withPassword: password)
                ) { result in
                    switch result {
                    case .success(let user):
                        completionHandler(user)
                    case .failure:
                        XCTFail("Failed to log in with username/password provider")
                    }
                }
            }
        }
    }
    
    private func prepareService() throws {
        let app = try self.createApp()
        self.app = app.1
        _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon)
        let svc = try self.addService(
            toApp: app.1,
            withType: "mongodb",
            withName: "mongodb1",
            withConfig: ServiceConfigs.mongodb(
                name: "mongodb1", uri: mongodbUri
            )
        )

        self.svcId = svc.0.id
        _ = try self.addRule(
            toService: svc.1,
            withConfig: RuleCreator.mongoDb(
                database: dbName,
                collection: collName,
                roles: [RuleCreator.Role(
                    read: true, write: true
                    )],
                schema: RuleCreator.Schema(properties: Document()))
        )

        _ = try self.addProvider(toApp: self.app,
                                 withConfig: .userpass(
                                    emailConfirmationURL: "http://emailConfirmUrl.com",
                                    resetPasswordURL: "http://resetPasswordUrl.com",
                                    confirmEmailSubject: "email subject",
                                    resetPasswordSubject: "password subject"))

        self.client = try self.appClient(forApp: app.0)
    }

    func testCustomUserData() throws {
        try prepareService()
        try self.app.customUserData.create(
            data: CustomUserConfigData(mongoServiceId: svcId,
                                       databaseName: dbName,
                                       collectionName: collName,
                                       userIdField: "recoome",
                                       enabled: true), empty: true)
        _ = try self.app.functions.create(data: FunctionCreator.init(
            name: "addUserProfile",
            source: """
            exports = async function(color) {
            const coll = context.services.get("mongodb1")
            .db("\(dbName)").collection("\(collName)");
            await coll.insertOne({
            "recoome": context.user.id,
            "favoriteColor": "blue"
            });
            return true;
            }
            """,
            canEvaluate: nil,
            isPrivate: false))

        var exp = expectation(description: "will login")
        var user: StitchUser!

        try registerAndLogin { stitchUser in
            user = stitchUser
            exp.fulfill()
        }

        waitForExpectations(timeout: 10)

        XCTAssertEqual(user.customData, [:])
        exp = expectation(description: "will add favorite color")
        client.callFunction(withName: "addUserProfile", withArgs: ["blue"], { (res: StitchResult<Bool>) in
            switch res {
            case .failure(let error):
                XCTFail("could not add user profile: \(error.description)")
            case .success(let result):
                XCTAssert(result)
            }
            exp.fulfill()
        })
        waitForExpectations(timeout: 10)
        XCTAssertEqual(user.customData, [:])

        exp = expectation(description: "will refresh custom data")
        client.auth.refreshCustomData({ _ in
            exp.fulfill()
        })
        waitForExpectations(timeout: 10)

        XCTAssertEqual(user.customData["favoriteColor"] as? String, "blue")

        exp = expectation(description: "will logout")
        client.auth.logout { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 10)

        client.auth.login(withCredential: UserPasswordCredential(withUsername: StitchCustomUserDataIntTests.email, withPassword: StitchCustomUserDataIntTests.pass), { res in
            switch res {
            case .failure(let error):
                XCTFail("could not add user profile: \(error.description)")
            case .success(let user):
                XCTAssertEqual(user.customData["favoriteColor"] as? String, "blue")
            }
            exp.fulfill()
        })
    }
}
