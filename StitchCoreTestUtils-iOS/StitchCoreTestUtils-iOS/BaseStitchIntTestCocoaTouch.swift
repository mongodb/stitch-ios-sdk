import Foundation
import StitchCoreTestUtils
import StitchCore
import StitchCore_iOS
import StitchCoreAdminClient
import XCTest

let stitchBaseURLProp = "stitch.baseURL"

open class BaseStitchIntTestCocoaTouch: BaseStitchIntTest {
    var clients = [StitchAppClient]()
    
    private lazy var pList: [String: Any]? = {
        let testBundle = Bundle(for: BaseStitchIntTestCocoaTouch.self)
        guard let url = testBundle.url(forResource: "Info", withExtension: "plist"),
            let myDict = NSDictionary(contentsOf: url) as? [String:Any] else {
                return nil
        }
        
        return myDict
    }()
    
    override open func setUp() {
        super.setUp()
        
        do { try Stitch.initialize() }
        catch { XCTFail(error.localizedDescription) }
    }
    
    override open func tearDown() {
        super.tearDown()
        clients.forEach { $0.auth.logout { _ in } }
    }
    
    override open var stitchBaseURL: String {
        return (pList?[stitchBaseURLProp] as? String) ?? "http://localhost:9090"
    }
    
    public func appClient(forApp app: AppResponse) throws -> StitchAppClient {
        if let appClient = try? Stitch.getAppClient(forAppId: app.clientAppId) {
            return appClient
        }

        let client = try Stitch.initializeAppClient(withConfigBuilder: StitchAppClientConfigurationBuilder {
            $0.clientAppId = app.clientAppId
            $0.baseURL = stitchBaseURL
        })
            
        clients.append(client)
        return client
    }
    
    // Registers a new email/password user, and logs them in, returning the user's ID
    public func registerAndLoginWithUserPass(
        app: Apps.App,
        client: StitchAppClient,
        email: String,
        pass: String
    ) throws -> String {
        let emailPassClient = client.auth.providerClient(forProvider:
            StitchCore_iOS.UserPasswordAuthProvider.clientSupplier
        )
        
        let exp0 = expectation(description: "should register")
        emailPassClient.register(withEmail: email, withPassword: pass) { _ in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        
        let conf = try app.userRegistrations.sendConfirmation(toEmail: email)
        
        let exp1 = expectation(description: "should confirm user")
        emailPassClient.confirmUser(withToken: conf.token, withTokenId: conf.tokenId) { _ in
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        let exp2 = expectation(description: "should login")
        var user: StitchUser!
        client.auth.login(withCredential: UserPasswordCredential(withUsername: email, withPassword: pass)) { (stitchUser, _) in
            user = stitchUser
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
        
        return user.id
    }
}
