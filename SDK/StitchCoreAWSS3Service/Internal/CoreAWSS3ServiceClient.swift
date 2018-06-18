import Foundation


public final class CoreAWSS3ServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    // An enumeration of the types that can be used in a put object request.
    private enum PutObjectBody {
        case string(String)
        case bsonBinary(Binary)
        case data(Data)
    }
    
    private func putObjectInternal(bucket: String,
                                   key: String,
                                   acl: String,
                                   contentType: String,
                                   body: PutObjectBody,
                                   timeout: TimeInterval? = nil) throws -> AWSS3PutObjectResult {
        var args: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType
        ]
        
        let bodyKey = "body"
        
        switch body {
        case .string(let stringVal):
            args[bodyKey] = stringVal
        case .bsonBinary(let binaryVal):
            args[bodyKey] = binaryVal
        case .data(let dataVal):
            args[bodyKey] = Binary.init(data: dataVal, subtype: .binary)
        }
        
        return try self.service.callFunctionInternal(
            withName: "put",
            withArgs: [args],
            withRequestTimeout: timeout
        )
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: String,
                          timeout: TimeInterval? = nil) throws -> AWSS3PutObjectResult {
        return try putObjectInternal(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: .string(body),
            timeout: timeout
        )
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Binary,
                          timeout: TimeInterval? = nil) throws -> AWSS3PutObjectResult {
        return try putObjectInternal(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: .bsonBinary(body),
            timeout: timeout
        )
    }
    
    public func putObject(bucket: String,
                          key: String,
                          acl: String,
                          contentType: String,
                          body: Data,
                          timeout: TimeInterval? = nil) throws -> AWSS3PutObjectResult {
        return try putObjectInternal(
            bucket: bucket,
            key: key,
            acl: acl,
            contentType: contentType,
            body: .data(body),
            timeout: timeout
        )
    }
    
    public func signPolicy(bucket: String,
                           key: String,
                           acl: String,
                           contentType: String) throws -> AWSS3SignPolicyResult {
        let args: Document = [
            "bucket": bucket,
            "key": key,
            "acl": acl,
            "contentType": contentType
        ]
        
        return try service.callFunctionInternal(
            withName: "signPolicy", withArgs: [args], withRequestTimeout: nil)
    }
}
