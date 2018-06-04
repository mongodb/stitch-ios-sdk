import Foundation
import MongoSwift
import StitchCore
import StitchCore_iOS
import StitchCoreServicesAwsS3

public final class AwsS3ServiceClientImpl: AwsS3ServiceClient {
    private let proxy: CoreAwsS3ServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreAwsS3ServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: String,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
        }
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: String,
                          timeout: TimeInterval,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body,
                timeout: timeout
            )
        }
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Data,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
        }
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Data,
                          timeout: TimeInterval,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body,
                timeout: timeout
            )
        }
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Binary,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body
            )
        }
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Binary,
                          timeout: TimeInterval,
                          _ completionHandler: @escaping (AwsS3PutObjectResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.putObject(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType,
                body: body,
                timeout: timeout
            )
        }
    }
    
    public func signPolicy(bucket: String,
                           key: String,
                           acl: String,
                           contentType: String,
                           _ completionHandler: @escaping (AwsS3SignPolicyResult?, Error?) -> Void) {
        self.dispatcher.run(withCompletionHandler: completionHandler) {
            return try self.proxy.signPolicy(
                bucket: bucket,
                key: key,
                acl: acl,
                contentType: contentType
            )
        }
    }
}
