import XCTest
import MockUtils
import MongoSwift
import StitchCore
import StitchCoreMocks
@testable import StitchCoreServicesAwsS3

final class CoreAwsS3ServiceClientUnitTests: XCTestCase {
    func testPutObjectString() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreAwsS3ServiceClient(withService: service)
        
        let bucket = "stuff"
        let key = "myFile"
        let acl = "public-read"
        let contentType = "plain/text"
        let body = "some data yo"
        
        let expectedLocation = "awsLocation"
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: AwsS3PutObjectResult.init(location: expectedLocation),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        let result = try client.putObject(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: body
        )
        
        XCTAssertEqual(expectedLocation, result.location)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("put", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType,
            "body": body
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testPutObjectBinary() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreAwsS3ServiceClient(withService: service)
        
        let bucket = "stuff"
        let key = "myFile"
        let acl = "public-read"
        let contentType = "plain/text"
        let body = Binary.init(data: "some data yo".data(using: .utf8)!, subtype: .binary)
        
        let expectedLocation = "awsLocation"
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: AwsS3PutObjectResult.init(location: expectedLocation),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        let result = try client.putObject(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: body
        )
        
        XCTAssertEqual(expectedLocation, result.location)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("put", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType,
            "body": body
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testPutObjectData() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreAwsS3ServiceClient(withService: service)
        
        let bucket = "stuff"
        let key = "myFile"
        let acl = "public-read"
        let contentType = "plain/text"
        let body = "some data yo".data(using: .utf8)!
        
        let expectedLocation = "awsLocation"
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: AwsS3PutObjectResult.init(location: expectedLocation),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        let result = try client.putObject(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: body
        )
        
        XCTAssertEqual(expectedLocation, result.location)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("put", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType,
            "body": Binary.init(data: body, subtype: .binary)
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
    
    func testSignPolicy() throws {
        let service = MockCoreStitchServiceClient()
        let client = CoreAwsS3ServiceClient(withService: service)
        
        let bucket = "stuff"
        let key = "myFile"
        let acl = "public-read"
        let contentType = "plain/text"
        
        let expectedPolicy = "you shall not"
        let expectedSignature = "yoursTruly"
        let expectedAlgorithm = "DES-111"
        let expectedDate = "01-101-2012"
        let expectedCredential = "someCredential"
        
        service.callFunctionInternalWithDecodingMock.doReturn(
            result: AwsS3SignPolicyResult.init(policy: expectedPolicy,
                                               signature: expectedSignature,
                                               algorithm: expectedAlgorithm,
                                               date: expectedDate,
                                               credential: expectedCredential),
            forArg1: .any, forArg2: .any, forArg3: .any
        )
        
        let result = try client.signPolicy(bucket: bucket, key: key, acl: acl, contentType: contentType)
        
        XCTAssertEqual(expectedPolicy, result.policy)
        XCTAssertEqual(expectedSignature, result.signature)
        XCTAssertEqual(expectedAlgorithm, result.algorithm)
        XCTAssertEqual(expectedDate, result.date)
        XCTAssertEqual(expectedCredential, result.credential)
        
        let (funcNameArg, funcArgsArg, _) = service.callFunctionInternalWithDecodingMock.capturedInvocations.last!
        
        XCTAssertEqual("signPolicy", funcNameArg)
        XCTAssertEqual(1, funcArgsArg.count)
        
        let expectedArgs: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType
        ]
        
        XCTAssertEqual(expectedArgs, funcArgsArg[0] as? Document)
        
        // should pass along errors
        service.callFunctionInternalWithDecodingMock.doThrow(
            error: StitchError.serviceError(withMessage: "", withServiceErrorCode: .unknown),
            forArg1: .any,
            forArg2: .any,
            forArg3: .any
        )
        
        do {
            _ = try client.signPolicy(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType
            )
            XCTFail("function did not fail where expected")
        } catch {
            // do nothing
        }
    }
}
