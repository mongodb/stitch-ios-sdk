import XCTest
import MongoSwift
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchCoreAWSS3Service
@testable import StitchAWSS3Service

let testAWSAccessKeyID = TEST_AWS_ACCESS_KEY_ID.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] : TEST_AWS_ACCESS_KEY_ID
let testAWSSecretAccessKey = TEST_AWS_SECRET_ACCESS_KEY.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] : TEST_AWS_SECRET_ACCESS_KEY

class AWSS3ServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    override func setUp() {
        super.setUp()

        guard !(testAWSAccessKeyID?.isEmpty ?? true),
            !(testAWSSecretAccessKey?.isEmpty ?? true) else {
                XCTFail("No AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY in preprocessor macros; failing test. See README for more details.")
                return
        }
    }

    func testPutObject() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "aws-s3",
            withName: "aws-s31",
            withConfig: ServiceConfigs.awsS3(
                name: "aws-s31",
                region: "us-east-1",
                accessKeyID: testAWSAccessKeyID!,
                secretAccessKey: testAWSSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.awsS3(put: true,
                                                                                               signPolicy: true)))
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _ in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let awsS3 = client.serviceClient(fromFactory: awsS3ServiceClientFactory, withName: "aws-s31")
        
        // Putting to an bad bucket should fail
        let bucket = "notmystuff"
        let key = ObjectId.init().description
        let acl = "public-read"
        let contentType = "plain/text"
        let body = "hello again friend; did you miss me"
        
        let exp1 = expectation(description: "should not put object")
        awsS3.putObject(bucket: bucket, key: key, acl: acl, contentType: contentType, body: body) { result in
            switch result {
            case .success:
                XCTFail("expected a failure")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.awsError, withServiceErrorCode)
                default:
                    XCTFail("unexpected error")
                }
            }

            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        // Putting with all good params for S3 should work
        let bucketGood = "stitch-test-sdkfiles"
        let expectedLocation = "https://stitch-test-sdkfiles.s3.amazonaws.com/\(key)"
        let transport = FoundationHTTPTransport()
        
        let exp2 = expectation(description: "should put BSON binary")
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: body) { result in
            switch result {
            case .success(let awsS3Result):
                XCTAssertEqual(expectedLocation, awsS3Result.location)
            case .failure:
                XCTFail("unexpected error")
            }
  
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
        
        var httpResult = try transport.roundTrip(request: RequestBuilder()
            .with(method: .get)
            .with(url: expectedLocation)
            .with(timeout: 1.5)
            .build()
        )
        
        XCTAssertEqual(body, String.init(data: httpResult.body!, encoding: .utf8))
        
        // ...with BSON binary parameter
        let bodyBin = Binary(data: body.data(using: .utf8)!, subtype: .binary)
        
        let exp3 = expectation(description: "should put string")
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: bodyBin) { result in
            switch result {
            case .success(let awsS3Result):
                XCTAssertEqual(expectedLocation, awsS3Result.location)
            case .failure:
                XCTFail("unexpected error")
            }

            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 5.0)
        
        httpResult = try transport.roundTrip(request: RequestBuilder()
            .with(method: .get)
            .with(url: expectedLocation)
            .with(timeout: 1.5)
            .build()
        )
        
        XCTAssertEqual(bodyBin.data, httpResult.body!)
        
        // ...with Foundation Data parameter
        let bodyData = body.data(using: .utf8)!
        
        let exp4 = expectation(description: "should put Foundation Data")
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: bodyData) { result in
            switch result {
            case .success(let awsS3Result):
                XCTAssertEqual(expectedLocation, awsS3Result.location)
            case .failure:
                XCTFail("unexpected error")
            }
            
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: 5.0)
        
        httpResult = try transport.roundTrip(request: RequestBuilder()
            .with(method: .get)
            .with(url: expectedLocation)
            .with(timeout: 1.5)
            .build()
        )
        
        XCTAssertEqual(bodyData, httpResult.body!)
        
        // Excluding any required parameters should fail
        let exp5 = expectation(description: "should not put object")
        awsS3.putObject(bucket: "", key: key, acl: acl, contentType: contentType, body: body) { result in
            switch result {
            case .success:
                XCTFail("expected a failure")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
                default:
                    XCTFail("unexpected error")
                }
            }

            exp5.fulfill()
        }
        wait(for: [exp5], timeout: 5.0)
    }
    
    func testSignPolicy() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "aws-s3",
            withName: "aws-s31",
            withConfig: ServiceConfigs.awsS3(
                name: "aws-s31",
                region: "us-east-1",
                accessKeyID: testAWSAccessKeyID!,
                secretAccessKey: testAWSSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.awsS3(put: true,
                                                                                               signPolicy: true)))
        
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let awsS3 = client.serviceClient(fromFactory: awsS3ServiceClientFactory, withName: "aws-s31")
        
        // Including all parameters should succeed
        let bucket = "notmystuff"
        let key = ObjectId.init().description
        let acl = "public-read"
        let contentType = "plain/text"
        
        let exp1 = expectation(description: "should sign policy")
        awsS3.signPolicy(bucket: bucket, key: key, acl: acl, contentType: contentType) { result in
            switch result {
            case .success(let signPolicyResult):
                XCTAssertFalse(signPolicyResult.algorithm.isEmpty)
                XCTAssertFalse(signPolicyResult.credential.isEmpty)
                XCTAssertFalse(signPolicyResult.date.isEmpty)
                XCTAssertFalse(signPolicyResult.policy.isEmpty)
                XCTAssertFalse(signPolicyResult.signature.isEmpty)
            case .failure:
                XCTFail("unexpected error")
            }
            
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        // Excluding any required parameters should fail
        let exp2 = expectation(description: "should not sign policy")
        awsS3.signPolicy(bucket: "", key: key, acl: acl, contentType: contentType) { result in
            switch result {
            case .success:
                XCTFail("expected a failure")
            case .failure(let error):
                switch error {
                case .serviceError(_, let withServiceErrorCode):
                    XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
                default:
                    XCTFail("unexpected error")
                }
            }
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
    }
    
}
