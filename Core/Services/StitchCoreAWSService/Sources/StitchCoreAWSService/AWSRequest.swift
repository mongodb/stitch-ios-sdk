import Foundation
import MongoSwift

/**
 * An error that the `AWSRequestBuilder` can throw if it is missing certain configuration properties.
 */
public enum AWSRequestBuilderError: Error {
    case missingService
    case missingAction
}

/**
 * An AWSRequest encapsulates the details of an AWS request over the AWS service.
 */
public struct AWSRequest {
    /**
     * The service that the action in the request will be performed against.
     */
    public let service: String
    
    /**
     * The action within the AWS service to perform.
     */
    public let action: String
    
    /**
     * The region that service in this request should be scoped to.
     */
    public let region: String?
    
    /**
     * The arguments that will be used in the action.
     */
    public let arguments: Document
}

/**
 * A builder that can build an `AWSRequest`
 */
public class AWSRequestBuilder {
    internal var service: String?
    internal var action: String?
    internal var region: String?
    internal var arguments: Document?
    
    /**
     * Initializes a new builder for an AWS request.
     */
    public init() { }
    
    /**
     * Sets the service that the action in the request will be performed against.
     */
    @discardableResult
    public func with(service: String) -> Self {
        self.service = service
        return self
    }
    
    /**
     * Sets the action within the AWS service to perform.
     */
    @discardableResult
    public func with(action: String) -> Self {
        self.action = action
        return self
    }
    
    /**
     * Sets the region that service in this request should be scoped to.
     */
    @discardableResult
    public func with(region: String) -> Self {
        self.region = region
        return self
    }
    
    /**
     * Sets the arguments that will be used in the action.
     */
    @discardableResult
    public func with(arguments: Document) -> Self {
        self.arguments = arguments
        return self
    }
    
    /**
     * Builds, validates, and returns the `AWSRequest`.
     */
    public func build() throws -> AWSRequest {
        guard let service = service, service != "" else {
            throw AWSRequestBuilderError.missingService
        }
        
        guard let action = action, action != "" else {
            throw AWSRequestBuilderError.missingAction
        }
        
        return AWSRequest.init(
            service: service,
            action: action,
            region: region,
            arguments: arguments ?? Document.init()
        )
    }
}
