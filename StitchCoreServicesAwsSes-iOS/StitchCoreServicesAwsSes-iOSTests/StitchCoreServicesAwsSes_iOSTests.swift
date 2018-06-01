import XCTest

import StitchCore
import StitchCoreAdminClient
import StitchCoreTestUtils_iOS
import StitchCoreServicesAwsSes
@testable import StitchCoreServicesAwsSes_iOS

class StitchCoreServicesAwsSes_iOSTests: BaseStitchIntTestCocoaTouch {
    private let awsAccessKeyIdProp = "test.stitch.accessKeyId"
    private let awsSecretAccessKeyProp = "test.stitch.secretAccessKey"
    
    private lazy var pList: [String: Any]? = {
        let testBundle = Bundle(for: StitchCoreServicesAwsSes_iOSTests.self)
        guard let url = testBundle.url(forResource: "Info", withExtension: "plist"),
            let myDict = NSDictionary(contentsOf: url) as? [String:Any] else {
                return nil
        }
        
        return myDict
    }()
    
    private lazy var awsAccessKeyId: String? = pList?[awsAccessKeyIdProp] as? String
    private lazy var awsSecretAccessKey: String? = pList?[awsSecretAccessKeyProp] as? String
    
    override func setUp() {
        super.setUp()
        
        guard awsAccessKeyId != nil && awsAccessKeyId != "<your-access-key-id>",
              awsSecretAccessKey != nil && awsSecretAccessKey != "<your-secret-access-key>" else {
                XCTFail("No AWS Access Key ID, or Secret Access Key in properties; failing test. See README for more details.")
                return
        }
    }
    
    func testSendEmail() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "aws-ses",
            withName: "aws-ses1",
            withConfig: ServiceConfigs.awsSes(
                name: "aws-ses1",
                region: "us-east-1", accessKeyId: awsAccessKeyId!, secretAccessKey: awsSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.init(name: "rule",
                                                          actions: RuleActionsCreator.awsSes(send: true)))

        let client = try self.appClient(forApp: app.0)

        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _,_  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)

        let awsSes = client.serviceClient(forFactory: AwsSesService.sharedFactory, withName: "aws-ses1")

        // Sending a random email to an invalid email should fail
        let to = "eliot@stitch-dev.10gen.cc"
        let from = "dwight@10gen"
        let subject = "Hello"
        let body = "again friend"

        let exp1 = expectation(description: "should not send email")
        awsSes.sendEmail(to: to, from: from, subject: subject, body: body) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.awsError, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)

        // Sending with all good params for SES should work
        let fromGood = "dwight@baas-dev.10gen.cc"

        let exp2 = expectation(description: "should send email")
        awsSes.sendEmail(to: to, from: fromGood, subject: subject, body: body) { (result, _) in
            XCTAssertNotNil(result)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)

        // Excluding any required parameters should fail
        let exp3 = expectation(description: "should have invalid params")
        awsSes.sendEmail(to: to, from: "", subject: subject, body: body) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 5.0)
    }
}
