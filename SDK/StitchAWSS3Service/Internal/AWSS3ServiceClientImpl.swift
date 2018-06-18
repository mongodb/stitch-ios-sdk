import Foundation

public final class AWSS3ServiceClientImpl: AWSS3ServiceClient {
    private let proxy: CoreAWSS3ServiceClient
    private let dispatcher: OperationDispatcher
    
    internal init(withClient client: CoreAWSS3ServiceClient,
                  withDispatcher dispatcher: OperationDispatcher) {
        self.proxy = client
        self.dispatcher = dispatcher
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: String,
                          _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void) {
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
                          _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void) {
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
                          _ completionHandler: @escaping (StitchResult<AWSS3PutObjectResult>) -> Void) {
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
    
    public func signPolicy(bucket: String,
                           key: String,
                           acl: String,
                           contentType: String,
                           _ completionHandler: @escaping (StitchResult<AWSS3SignPolicyResult>) -> Void) {
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
