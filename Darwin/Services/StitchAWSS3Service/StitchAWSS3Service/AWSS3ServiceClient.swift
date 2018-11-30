import Foundation
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAWSS3Service

private final class AWSS3NamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = AWSS3ServiceClient

    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> AWSS3ServiceClient {
        return AWSS3ServiceClientImpl(
            withClient: CoreAWSS3ServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * Global factory const which can be used to create an `AWSS3ServiceClient` with a `StitchAppClient`. Pass into
 * `StitchAppClient.serviceClient(fromFactory:withName)` to get an `AWSS3ServiceClient.
 */
@available(*, deprecated, message: "Use awsServiceClientFactory instead")
public let awsS3ServiceClientFactory =
    AnyNamedServiceClientFactory<AWSS3ServiceClient>(factory: AWSS3NamedServiceClientFactory())

/**
 * The AWS S3 service client, which can be used to interact with AWS Simple Storage Service (S3) via MongoDB Stitch.
 * This client is deprecated. Use the AWSServiceClient in StitchAWSService.
 */
@available(*, deprecated, message: "Use AWSServiceClient instead")
public protocol AWSS3ServiceClient {

    // Disabled line length rule due to https://github.com/realm/jazzy/issues/896
    // swiftlint:disable line_length

    // We are disabling this because this is a deprecated library, and the new AWS service has the more reasonable
    // approach of an AWSRequest object as a parameter.
    // swiftlint:disable function_parameter_count

    /**
     * Puts an object into an AWS S3 bucket as a string.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a string
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the put request as an
     *                          `AWSS3PutObjectResult.`
     */
    func putObject(bucket: String, key: String, acl: String, contentType: String, body: String, _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void)

    /**
     * Puts a binary object into an AWS S3 bucket as a Foundation `Data` object.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a `Data`
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the put request as an
     *                          `AWSS3PutObjectResult.`
     */
    func putObject(bucket: String, key: String, acl: String, contentType: String, body: Data, _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void)

    /**
     * Puts a binary object into an AWS S3 bucket as a BSON `Binary` object.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a BSON `Binary`
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the put request as an
     *                          `AWSS3PutObjectResult.`
     */
    func putObject(bucket: String, key: String, acl: String, contentType: String, body: Binary, _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void)

    /**
     * Signs an AWS S3 security policy for a future put object request. This future request would
     * be made outside of the Stitch SDK. This is typically used for large requests that are better
     * sent directly to AWS.
     *
     * - seealso:
     * [Uploading a File to Amazon S3 Using HTTP POST]
     * (https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html)
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - completionHandler: The completion handler to call when the policy is signed or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain the result of the sign policy request as an
     *                          `AWSS3SignPolicyResult.`
     */
    func signPolicy(bucket: String, key: String, acl: String, contentType: String, _ completionHandler: @escaping (StitchResult<AWSS3SignPolicyResult>) -> Void)
}
