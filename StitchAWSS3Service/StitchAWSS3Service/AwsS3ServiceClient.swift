import Foundation
import MongoSwift
import StitchCore
import StitchCoreSDK
import StitchCoreAWSS3Service

private final class AwsS3NamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = AwsS3ServiceClient
    
    func client(withServiceClient serviceClient: StitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> AwsS3ServiceClient {
        return AwsS3ServiceClientImpl(
            withClient: CoreAwsS3ServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

public protocol AwsS3ServiceClient {
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
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: String,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
    /**
     * Puts an object into an AWS S3 bucket as a string. A timeout can be specified if the operation is expected to
     * take longer than the default timeout configured for the Stitch app client.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a string
     *     - timeout: the number of seconds to wait for the put request to complete before timing out
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: String,
        timeout: TimeInterval,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
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
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: Data,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
    /**
     * Puts an object into an AWS S3 bucket as a Foundation `Data` object.. A timeout can be specified if the operation
     * is expected to take longer than the default timeout configured for the Stitch app client.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a `Data`
     *     - timeout: the number of seconds to wait for the put request to complete before timing out
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: Data,
        timeout: TimeInterval,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
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
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: Binary,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
    /**
     * Puts an object into an AWS S3 bucket as a BSON `Binary` object. A timeout can be specified if the operation
     * is expected to take longer than the default timeout configured for the Stitch app client.
     *
     * - parameters:
     *     - bucket: the bucket to put the object in
     *     - key: the key (or name) of the object
     *     - acl: the ACL to apply to the object (e.g. private)
     *     - contentType: the content type of the object (e.g. "application/json")
     *     - body: the body of the object as a BSON `Binary`
     *     - timeout: the number of seconds to wait for the put request to complete before timing out
     *     - completionHandler: The completion handler to call when the object is put or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func putObject(
        bucket: String,
        key: String,
        acl: String,
        contentType: String,
        body: Binary,
        timeout: TimeInterval,
        _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void)
    
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
     */
    func signPolicy(bucket: String,
                    key: String,
                    acl: String,
                    contentType: String,
                    _ completionHandler: @escaping (AwsS3SignPolicyResult?, Error?) -> Void)
}

public final class AwsS3Service {
    public static let sharedFactory = AnyNamedServiceClientFactory<AwsS3ServiceClient>(
        factory: AwsS3NamedServiceClientFactory()
    )
}
