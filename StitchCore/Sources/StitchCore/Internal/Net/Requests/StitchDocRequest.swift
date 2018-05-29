import Foundation
import MongoSwift

/**
 * An error that a `StitchDocRequestBuilder` can throw if it is missing certain configuration properties.
 */
public enum StitchDocRequestBuilderError: Error {
    case missingDocument
}

/**
 * A builder that can build a `StitchDocRequest` object.
 */
public class StitchDocRequestBuilder: StitchRequestBuilder {
    internal var document: Document?
    
    public override init() { super.init() }
    
    init(request: StitchDocRequest) {
        super.init(request: request)
        self.document = request.document
    }
    
    /**
     * Sets the BSON document that will become the body of the request to be built.
     */
    @discardableResult
    public func with(document: Document) -> StitchDocRequestBuilder{
        self.document = document
        return self
    }
    
    /**
     * Sets the HTTP method of the request to be built.
     */
    @discardableResult
    public override func with(method: Method) -> StitchDocRequestBuilder {
        self.method = method
        return self
    }
    
    /**
     * Sets the body of the request to be built. Will be overriden by the document specified.
     */
    @discardableResult
    public override func with(body: Data) -> StitchDocRequestBuilder {
        self.body = body
        return self
    }
    
    /**
     * Sets the HTTP headers of the request to be built.
     */
    @discardableResult
    public override func with(headers: [String: String]) -> StitchDocRequestBuilder {
        self.headers = headers
        return self
    }
    
    /**
     * Sets the number of seconds that the underlying transport should spend on an HTTP round trip before failing with
     * an error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    @discardableResult
    public override func with(timeout: TimeInterval) -> StitchDocRequestBuilder {
        self.timeout = timeout
        return self
    }
    
    /**
     * Sets the URL of the request to be built.
     */
    @discardableResult
    public override func with(path: String) -> StitchDocRequestBuilder {
        self.path = path
        return self
    }
    
    /**
     * Builds the `StitchDocRequest`.
     */
    public override func build() throws -> StitchDocRequest {
        guard let document = self.document else {
            throw StitchDocRequestBuilderError.missingDocument
        }
        
        let docString = document.canonicalExtendedJSON
        
        // computed properties can't throw errors, so `document.canonicalExtendedJSON`
        // returns an empty string if it could not encode the document
        if docString == "" {
            throw StitchError.requestError(
                withError: MongoError.bsonEncodeError(message: "could not encode document as extended JSON string"),
                withRequestErrorCode: .encodingError
            )
        }
        
        self.body = docString.data(using: .utf8)
        
        self.headers = self.headers ?? [:]
        self.headers![Headers.contentType.rawValue] = ContentTypes.applicationJson.rawValue
        
        return try StitchDocRequest.init(stitchRequest: super.build(), document: document)
    }
}

/**
 * An HTTP request that can be made to a Stitch server, which contains a BSON document as its body.
 */
public final class StitchDocRequest: StitchRequest {
    /**
     * The BSON document that will become the body of the request when it is performed.
     */
    public let document: Document
    
    internal init(stitchRequest: StitchRequest, document: Document) {
        self.document = document
        super.init(request: stitchRequest)
    }
}
