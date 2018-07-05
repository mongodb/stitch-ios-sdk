import XCTest

import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchCoreAWSSESService
@testable import StitchAWSSESService

let testAWSAccessKeyID = TEST_AWS_ACCESS_KEY_ID.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] : TEST_AWS_ACCESS_KEY_ID
let testAWSSecretAccessKey = TEST_AWS_SECRET_ACCESS_KEY.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] : TEST_AWS_SECRET_ACCESS_KEY

class AWSSESServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    override func setUp() {
        super.setUp()
        
        guard !(testAWSAccessKeyID?.isEmpty ?? true),
            !(testAWSSecretAccessKey?.isEmpty ?? true) else {
                XCTFail("No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY in preprocessor macros; failing test. See README for more details.")
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
                region: "us-east-1",
                accessKeyID: testAWSAccessKeyID!,
                secretAccessKey: testAWSSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.awsSes(send: true)))

        let client = try self.appClient(forApp: app.0)

        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)

        let awsSES = client.serviceClient(fromFactory: awsSESServiceClientFactory, withName: "aws-ses1")

        // Sending a random email to an invalid email should fail
        let to = "eliot@stitch-dev.10gen.cc"
        let from = "dwight@10gen"
        let subject = "Hello"
        let body = "again friend"

        let exp1 = expectation(description: "should not send email")
        awsSES.sendEmail(to: to, from: from, subject: subject, body: body) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.awsError, withServiceErrorCode)
                default:
                    XCTFail()
                }
            }
            
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)

        // Sending with all good params for SES should work
        let fromGood = "dwight@baas-dev.10gen.cc"

        let exp2 = expectation(description: "should send email")
        awsSES.sendEmail(to: to, from: fromGood, subject: subject, body: body) { result in
            switch result {
            case .success:
                break
            case .failure:
                XCTFail("unexpected error")
            }
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)

        // Excluding any required parameters should fail
        let exp3 = expectation(description: "should have invalid params")
        awsSES.sendEmail(to: to, from: "", subject: subject, body: body) { result in
            switch result {
            case .success:
                XCTFail("expected an error")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
                default:
                    XCTFail()
                }
            }
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 5.0)
    }
}
