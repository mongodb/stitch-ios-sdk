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
public final class StitchDocRequestBuilder: StitchRequestBuilder {
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
    public func with(document: Document) -> Self {
        self.document = document
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
        self.headers![Headers.contentType.rawValue] = ContentTypes.applicationJSON.rawValue
        
        return try StitchDocRequest.init(stitchRequest: super.build(), document: document)
    }
}

/**
 * An HTTP request that can be made to a Stitch server, which contains a BSON document as its body.
 */
public final class StitchDocRequest: StitchRequest {
    /**
     * Constructs a builder preset with this request's properties.
     */
    public override var builder: StitchDocRequestBuilder {
        return StitchDocRequestBuilder.init(request: self)
    }
    
    /**
     * The BSON document that will become the body of the request when it is performed.
     */
    public let document: Document
    
    internal init(stitchRequest: StitchRequest, document: Document) {
        self.document = document
        super.init(request: stitchRequest)
    }
    
    public static func ==(lhs: StitchDocRequest, rhs: StitchDocRequest) -> Bool {
        return lhs as StitchRequest == rhs as StitchRequest && lhs.document == rhs.document
    }
}
