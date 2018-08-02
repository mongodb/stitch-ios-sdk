import XCTest
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAdminClient
import StitchDarwinCoreTestUtils
import StitchCoreAWSService
@testable import StitchAWSService

let testAWSAccessKeyID = TEST_AWS_ACCESS_KEY_ID.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] : TEST_AWS_ACCESS_KEY_ID
let testAWSSecretAccessKey = TEST_AWS_SECRET_ACCESS_KEY.isEmpty ?
    ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] : TEST_AWS_SECRET_ACCESS_KEY

class AWSServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    
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
            withType: "aws",
            withName: "aws1",
            withConfig: ServiceConfigs.aws(
                name: "aws1",
                accessKeyID: testAWSAccessKeyID!,
                secretAccessKey: testAWSSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(
                                name: "default",
                                actions: RuleActionsCreator.aws(actions: ["s3:PutObject"])
                            ))
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _ in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let awsS3 = client.serviceClient(fromFactory: awsServiceClientFactory, withName: "aws1")
        
        // Putting to a bad bucket should fail
        let bucket = "notmystuff"
        let key = ObjectId.init().description
        let acl = "public-read"
        let contentType = "plain/text"
        let body = "hello again friend; did you miss me"
        
        let args1: Document = [
            "Bucket": bucket,
            "Key": key,
            "ACL": acl,
            "ContentType": contentType,
            "Body": body
        ]
        
        let exp1 = expectation(description: "should not put object")
        awsS3.execute(request: try AWSRequestBuilder()
            .with(service: "s3")
            .with(action: "PutObject")
            .with(arguments: args1)
            .build()) { result in
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
        
        let args2: Document = [
            "Bucket": bucketGood,
            "Key": key,
            "ACL": acl,
            "ContentType": contentType,
            "Body": body
        ]
        
        let exp2 = expectation(description: "should put string")
        awsS3.execute(request: try AWSRequestBuilder()
            .with(service: "s3")
            .with(action: "PutObject")
            .with(arguments: args2)
            .build()) { (result: StitchResult<Document>) in
            switch result {
            case .success(let awsS3Result):
                XCTAssertNotNil(awsS3Result["ETag"])
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
        
        let args3: Document = [
            "Bucket": bucketGood,
            "Key": key,
            "ACL": acl,
            "ContentType": contentType,
            "Body": bodyBin
        ]
        
        let exp3 = expectation(description: "should put BSON binary")
        awsS3.execute(request: try AWSRequestBuilder()
            .with(service: "s3")
            .with(action: "PutObject")
            .with(arguments: args3)
            .build()) { (result: StitchResult<Document>) in
            switch result {
            case .success(let awsS3Result):
                XCTAssertNotNil(awsS3Result["ETag"])
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
        
        // Excluding any required parameters should fail
        let exp4 = expectation(description: "should not put object")
        
        let args4: Document = [
            "Bucket": "",
            "Key": key,
            "ACL": acl,
            "ContentType": contentType,
            "Body": bodyBin
        ]
        
        awsS3.execute(request: try AWSRequestBuilder()
            .with(service: "s3")
            .with(action: "PutObject")
            .with(arguments: args4)
            .build()) { result in
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
            
            exp4.fulfill()
        }
        wait(for: [exp4], timeout: 5.0)
    }
    
}
