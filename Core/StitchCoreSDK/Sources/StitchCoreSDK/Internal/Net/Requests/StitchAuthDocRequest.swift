import Foundation
import MongoSwift

/**
 * A builder that can build a `StitchAuthDocRequest` object.
 */
public final class StitchAuthDocRequestBuilder: StitchAuthRequestBuilder {
    /**
     * The BSON document that will become the body of the request to be built.
     */
    internal var document: Document?
    
    public override init() { super.init() }
    
    init(request: StitchAuthDocRequest) {
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
     * Builds the `StitchAuthDocRequest`.
     */
    public override func build() throws -> StitchAuthDocRequest {
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
        
        return try StitchAuthDocRequest.init(stitchAuthRequest: super.build(), document: document)
    }
}

/**
 * An authenticated HTTP request that can be made to a Stitch server, which contains a BSON document as its body.
 */
public final class StitchAuthDocRequest: StitchAuthRequest {
    /**
     * Constructs a builder preset with this request's properties.
     */
    public override var builder: StitchAuthDocRequestBuilder {
        return StitchAuthDocRequestBuilder.init(request: self)
    }
    
    /**
     * The BSON document that will become the body of the request when it is performed.
     */
    public let document: Document
    
    /**
     * Convert an authenticated Stitch request into an authenticated Stitch request with a document body.
     */
    internal init(stitchAuthRequest: StitchAuthRequest, document: Document) {
        self.document = document
        super.init(stitchAuthRequest: stitchAuthRequest)
    }
    
    /**
     * Convert a normal Stitch request into an authenticated Stitch request with a document body.
     */
    internal init(stitchRequest: StitchRequest, document: Document) {
        self.document = document
        super.init(stitchRequest: stitchRequest, useRefreshToken: false)
    }
    
    public static func ==(lhs: StitchAuthDocRequest, rhs: StitchAuthDocRequest) -> Bool {
        return lhs as StitchAuthRequest == rhs as StitchAuthRequest && lhs.document == rhs.document
    }
}
