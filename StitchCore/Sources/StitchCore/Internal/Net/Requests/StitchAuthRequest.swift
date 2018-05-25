import MongoSwift
import Foundation

/**
 * A protocol defining the configuration properties necessary to build a `StitchAuthRequest`.
 */
public protocol StitchAuthRequestBuilder: StitchRequestBuilder {
    /**
     * Whether or not the request to be built should use the refresh token instead of the temporary access token.
     */
    var useRefreshToken: Bool? { get set }

    /**
     * Whether or not the request client carrying out this request should attempt to refresh the access token and retry
     * the operation if there was an invalid sesion error.
     */
    var shouldRefreshOnFailure: Bool? { get set }
}

/**
 * A builder that can build a `StitchAuthRequest` object.
 */
public struct StitchAuthRequestBuilderImpl: StitchAuthRequestBuilder {
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchAuthRequestImpl

    /**
     * Whether or not the request to be built should use the refresh token instead of the temporary access token.
     */
    public var useRefreshToken: Bool?

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
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
     * request.
     */
    public var timeout: TimeInterval?

    /**
     * The HTTP headers of the request to be built.
     */
    public var headers: [String: String]?

    /**
     * The body of the request to be built.
     */
    public var body: Data?

    /**
     * Whether or not the request client carrying out the request to be built should attempt to refresh the access
     * token and retry the operation if there was an invalid sesion error.
     */
    public var shouldRefreshOnFailure: Bool?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchAuthRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchAuthRequest` as a `StitchAuthRequestImpl`.
     */
    public func build() throws -> StitchAuthRequestImpl {
        return try StitchAuthRequestImpl.init(self)
    }
}

/**
 * A protocol representing an authenticated HTTP request that can be made to a Stitch server.
 */
public protocol StitchAuthRequest: StitchRequest {
    /**
     * Whether or not the request should use the refresh token instead of the temporary access token.
     */
    var useRefreshToken: Bool { get }

    /**
     * Whether or not the request client carrying out this request should attempt to refresh the access token and retry
     * the operation if there was an invalid sesion error.
     */
    var shouldRefreshOnFailure: Bool { get }
}

/**
 * An implementation of `StitchAuthRequest`.
 */
public struct StitchAuthRequestImpl: StitchAuthRequest {
    /**
     * The type that builds this request object.
     */
    public typealias TBuilder = StitchAuthRequestBuilderImpl

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
     * Whether or not the request should use the refresh token instead of the temporary access token.
     */
    public let useRefreshToken: Bool

    /**
     * Whether or not the request client carrying out this request should attempt to refresh the access token and retry
     * the operation if there was an invalid sesion error.
     */
    public let shouldRefreshOnFailure: Bool

    /**
     * Initializes this request by accepting a `StitchAuthRequestBuilderImpl`.
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

        self.useRefreshToken = builder.useRefreshToken ?? false
        self.path = path
        self.method = method
        self.timeout = builder.timeout
        self.headers = builder.headers ?? [:]
        self.body = builder.body
        self.startedAt = Date().timeIntervalSince1970
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}

/**
 * A protocol defining the configuration properties necessary to build a `StitchAuthDocRequest`.
 */
public protocol StitchAuthDocRequestBuilder: StitchAuthRequestBuilder {
    /**
     * The BSON document that will become the body of the request to be built.
     */
    var document: Document? { get set }
}

/**
 * A builder that can build a `StitchAuthDocRequest` object.
 */
public struct StitchAuthDocRequestBuilderImpl: StitchAuthDocRequestBuilder {
    /**
     * The type that this builder builds.
     */
    public typealias TBuildee = StitchAuthDocRequest

    /**
     * The BSON document that will become the body of the request to be built.
     */
    public var document: Document?

    /**
     * Whether or not the request to be built should use the refresh token instead of the temporary access token.
     */
    public var useRefreshToken: Bool?

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
     * error. If not configured, a default should override it before the request is transformed into a plain HTTP
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
     * Whether or not the request client carrying out the request to be built should attempt to refresh the access
     * token and retry the operation if there was an invalid sesion error.
     */
    public var shouldRefreshOnFailure: Bool?

    /**
     * Initializes the builder with a closure that sets the builder's desired properties.
     */
    public init(_ builder: (inout StitchAuthDocRequestBuilderImpl) -> Void) {
        builder(&self)
    }

    /**
     * Builds the `StitchAuthDocRequest`.
     */
    public func build() throws -> StitchAuthDocRequest {
        return try StitchAuthDocRequest.init(self)
    }
}

/**
 * An autheneticated HTTP request that can be made to a Stitch server, which contains a BSON document as its body.
 */
public struct StitchAuthDocRequest: StitchAuthRequest {
    /**
     * Whether or not the request should use the refresh token instead of the temporary access token.
     */
    public var useRefreshToken: Bool

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
     * The BSON document that will become the body of the request.
     */
    public let document: Document

    /**
     * Whether or not the request client carrying out this request should attempt to refresh the access token and retry
     * the operation if there was an invalid sesion error.
     */
    public let shouldRefreshOnFailure: Bool

    /**
     * Initializes this request by accepting a `StitchAuthDocRequestBuilderImpl`.
     *
     * - throws: `RequestBuilderError` if the builder is missing an HTTP method or a URL, or
     *           `StitchDocRequestBuilderError` if the builder is missing a document.
     */
    public init(_ builder: StitchAuthDocRequestBuilderImpl) throws {
        guard let document = builder.document else {
            throw StitchDocRequestBuilderError.missingDocument
        }
        guard let path = builder.path else {
            throw RequestBuilderError.missingUrl
        }

        guard let method = builder.method else {
            throw RequestBuilderError.missingMethod
        }

        self.useRefreshToken = builder.useRefreshToken ?? false
        
        self.path = path
        self.method = method
        
        self.timeout = builder.timeout
        self.headers = builder.headers ?? [:]
        
        self.headers[Headers.contentType.rawValue] = ContentTypes.applicationJson.rawValue
        self.body = document.canonicalExtendedJSON.data(using: .utf8)
        
        self.startedAt = Date().timeIntervalSince1970
        self.document = document
        self.shouldRefreshOnFailure = builder.shouldRefreshOnFailure ?? true
    }
}
