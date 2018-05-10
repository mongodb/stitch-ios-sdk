import Foundation
import ExtendedJSON

/**
 * A protocol defining the configuration properties necessary to build a `StitchRequest`.
 */
public protocol StitchRequestBuilder: Builder {
    /**
     * The HTTP method of the request to be built.
     */
    var method: Method? { get set }

    /**
     * The HTTP headers of the request to be built.
     */
    var headers: [String: String]? { get set }
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    var timeout: TimeInterval? { get set }

    /**
     * The body of the rqeuest to be built.
     */
    var body: Data? { get set }

    /**
     * The URL of the request to be built.
     */
    var path: String? { get set }
}

/**
 * A builder that can build a `StitchRequest` object.
 */
public struct StitchRequestBuilderImpl: StitchRequestBuilder {
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchRequestImpl

    /**
     * The HTTP method of the request to be built.
     */
    public var method: Method?

    /**
     * The body of the request to be built.
     */
    public var body: Data?

    /**
     * The HTTP headers of the request to be built.
     */
    public var headers: [String: String]?
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public var timeout: TimeInterval?

    /**
     * The URL of the request to be built.
     */
    public var path: String?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchRequest` as a `StitchRequestImpl`.
     */
    public func build() throws -> StitchRequestImpl {
        return try StitchRequestImpl.init(self)
    }
}

/**
 * A protocol representing an HTTP request that can be made to a Stitch server.
 */
public protocol StitchRequest: Buildee {
    /**
     * The URL to which this request will be made.
     */
    var path: String { get }

    /**
     * The HTTP method of this request.
     */
    var method: Method { get }

    /**
     * The HTTP headers of this request.
     */
    var headers: [String: String] { get }
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    var timeout: TimeInterval? { get }

    /**
     * The body of the request.
     */
    var body: Data? { get }

    /**
     * A `TimeInterval` indicating the time that the request was made (since the Unix epoch).
     */
    var startedAt: TimeInterval { get }
}

/**
 * The implementation of `StitchRequest`.
 */
public struct StitchRequestImpl: StitchRequest {

    /**
     * The type that builds this request object.
     */
    public typealias TBuilder = StitchRequestBuilderImpl

    /**
     * The URL to which this request will be made.
     */
    public let path: String

    /**
     * The HTTP method of this request.
     */
    public let method: Method

    /**
     * The HTTP headers of this request.
     */
    public let headers: [String: String]

    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error.  If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public let timeout: TimeInterval?
    
    /**
     * The body of the request.
     */
    public let body: Data?

    /**
     * A `TimeInterval` indicating the time that the request was made (since the Unix epoch).
     */
    public let startedAt: TimeInterval

    /**
     * Initializes this request by accepting a `StitchRequestBuilderImpl`.
     *
     * - throws: `RequestBuilderError` if the builder is missing an HTTP method or a URL.
     */
    public init(_ builder: TBuilder) throws {
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.path = path
        self.method = method
        self.headers = builder.headers ?? [:]
        self.timeout = builder.timeout
        self.body = builder.body
        self.startedAt = Date().timeIntervalSince1970
    }
}

/**
 * An error that a `StitchDocRequestBuilder` can throw if it is missing certain configuration properties.
 */
public enum StitchDocRequestBuilderError: Error {
    case missingDocument
}

/**
 * A protocol defining the configuration properties necessary to build a `StitchDocRequest`.
 */
public protocol StitchDocRequestBuilder: StitchRequestBuilder {
    /**
     * The BSON document that will become the body of the request to be built.
     */
    var document: Document? { get set }
}

/**
 * A builder that can build a `StitchDocRequest` object.
 */
public struct StitchDocRequestBuilderImpl: StitchDocRequestBuilder {
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchDocRequest

    /**
     * The BSON document that will become the body of the request to be built.
     */
    public var document: Document?

    /**
     * The URL of the request to be built.
     */
    public var path: String?

    /**
     * The HTTP method of the request to be built.
     */
    public var method: Method?
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error.  If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public var timeout: TimeInterval?

    /**
     * The HTTP headers of the request to be built.
     */
    public var headers: [String: String]?

    /**
     * The body of the request to be built. This body will be overwritten with the contents of the BSON document
     * when the request is performed.
     */
    public var body: Data?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchDocRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchDocRequest`.
     */
    public func build() throws -> StitchDocRequest {
        return try StitchDocRequest.init(self)
    }
}

/**
 * An HTTP request that can be made to a Stitch server, which contains a BSON document as its body.
 */
public struct StitchDocRequest: StitchRequest {
    /**
     * The URL to which this request will be made.
     */
    public var path: String

    /**
     * The HTTP method of this request.
     */
    public var method: Method
    
    /**
     * The number of seconds that the underlying transport should spend on an HTTP round trip before failing with an
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public var timeout: TimeInterval?

    /**
     * The HTTP headers of this request.
     */
    public var headers: [String: String]

    /**
     * The body of the request.
     */
    public var body: Data?

    /**
     * A `TimeInterval` indicating the time that the request was made (since the Unix epoch).
     */
    public var startedAt: TimeInterval

    /**
     * The BSON document that will become the body of the request when it is performed.
     */
    public let document: Document

    /**
     * Initializes this request by accepting a `StitchDocRequestBuilderImpl`.
     *
     * - throws: `StitchDocRequestBuilderError` if the builder is missing a document, or a `RequestBuilderError` if
     *           the builder is missing an HTTP method or a URL.
     */
    public init(_ builder: StitchDocRequestBuilderImpl) throws {
        guard let document = builder.document else {
            throw StitchDocRequestBuilderError.missingDocument
        }
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }


        self.path = path
        self.method = method
        
        self.timeout = builder.timeout
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.document = document
        self.startedAt = Date().timeIntervalSince1970
    }
}
