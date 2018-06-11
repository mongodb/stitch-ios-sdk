import XCTest
import MongoSwift
import StitchCore
import StitchCoreAdminClient
import StitchCoreTestUtils_iOS
import StitchCoreServicesAwsS3
@testable import StitchCoreServicesAwsS3_iOS

class AwsS3ServiceClientIntTests: BaseStitchIntTestCocoaTouch {
    private let awsAccessKeyIdProp = "test.stitch.accessKeyId"
    private let awsSecretAccessKeyProp = "test.stitch.secretAccessKey"
    
    private lazy var pList: [String: Any]? = fetchPlist(type(of: self))
    
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

    func testPutObject() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "aws-s3",
            withName: "aws-s31",
            withConfig: ServiceConfigs.awsS3(
                name: "aws-s31",
                region: "us-east-1", accessKeyId: awsAccessKeyId!, secretAccessKey: awsSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.awsS3(put: true,
                                                                                               signPolicy: true)))
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _,_  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let awsS3 = client.serviceClient(forFactory: AwsS3Service.sharedFactory, withName: "aws-s31")
        
        // Putting to an bad bucket should fail
        let bucket = "notmystuff"
        let key = ObjectId.init().description
        let acl = "public-read"
        let contentType = "plain/text"
        let body = "hello again friend; did you miss me"
        
        let exp1 = expectation(description: "should not put object")
        awsS3.putObject(bucket: bucket, key: key, acl: acl, contentType: contentType, body: body) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.awsError, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        // Putting with all good params for S3 should work
        let bucketGood = "stitch-test-sdkfiles"
        let expectedLocation = "https://stitch-test-sdkfiles.s3.amazonaws.com/\(key)"
        let transport = FoundationHTTPTransport()
        
        let exp2 = expectation(description: "should put BSON binary")
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: body) { (result, _) in
            XCTAssertNotNil(result)
            
            XCTAssertEqual(expectedLocation, result?.location)
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
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: bodyBin) { (result, _) in
            XCTAssertNotNil(result)
            
            XCTAssertEqual(expectedLocation, result?.location)
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
        awsS3.putObject(bucket: bucketGood, key: key, acl: acl, contentType: contentType, body: bodyData) { (result, _) in
            XCTAssertNotNil(result)
            
            XCTAssertEqual(expectedLocation, result?.location)
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
        awsS3.putObject(bucket: "", key: key, acl: acl, contentType: contentType, body: body) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
            default:
                XCTFail()
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
                region: "us-east-1", accessKeyId: awsAccessKeyId!, secretAccessKey: awsSecretAccessKey!
            )
        )
        _ = try self.addRule(toService: svc.1,
                             withConfig: RuleCreator.actions(name: "rule",
                                                             actions: RuleActionsCreator.awsS3(put: true,
                                                                                               signPolicy: true)))
        
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _,_  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let awsS3 = client.serviceClient(forFactory: AwsS3Service.sharedFactory, withName: "aws-s31")
        
        // Including all parameters should succeed
        let bucket = "notmystuff"
        let key = ObjectId.init().description
        let acl = "public-read"
        let contentType = "plain/text"
        
        let exp1 = expectation(description: "should sign policy")
        awsS3.signPolicy(bucket: bucket, key: key, acl: acl, contentType: contentType) { (result, _) in
            XCTAssertNotNil(result)
            
            XCTAssertFalse(result!.algorithm.isEmpty)
            XCTAssertFalse(result!.credential.isEmpty)
            XCTAssertFalse(result!.date.isEmpty)
            XCTAssertFalse(result!.policy.isEmpty)
            XCTAssertFalse(result!.signature.isEmpty)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        // Excluding any required parameters should fail
        let exp2 = expectation(description: "should not sign policy")
        awsS3.signPolicy(bucket: "", key: key, acl: acl, contentType: contentType) { (_, error) in
            switch error as? StitchError {
            case .serviceError(_, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
    }
    
}
