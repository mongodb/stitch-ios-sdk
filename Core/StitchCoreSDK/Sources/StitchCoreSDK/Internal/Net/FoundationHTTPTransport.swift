import Foundation
import MongoSwift

/**
 * A basic implementation of the `Transport` protocol using the `URLSession.dataTask` method in the Foundation library.
 */
open class FoundationHTTPTransport: Transport {
    /**
     * Empty public initializer to make initialization of this Transport available outside of this module.
     */
    public init() {
    }

    /**
     * The round trip functionality for this Transport, which uses `URLSession.dataTask`.
     */
    open func roundTrip(request: Request) throws -> Response {
        let (response, _) = try doRoundTrip(request: request)
        return response
    }

    /**
     * The stream functionality for this Transport, which uses `URLSession.dataTask`.
     */
    open func stream(request: Request, delegate: SSEStreamDelegate? = nil) throws -> RawSSEStream {
        let (rawStream, _) = try doStream(request: request, delegate: delegate)
        return rawStream
    }

    /**
     * Performs a round trip using Foundation's HTTP libraries, and returns the Response, and the URLSessionDataTask
     * used to make the request.
     *
     * Note: This is intended for internal use only. Swift does not have a `protected` access modifier.
     */
    public final func doRoundTrip(request: Request) throws -> (Response, URLSessionDataTask) {
        guard let url = URL(string: request.url) else {
            throw StitchError.clientError(withClientErrorCode: .missingURL)
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = request.timeout

        let session = URLSession(configuration: sessionConfig)

        var urlRequest = URLRequest(url: url)

        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.rawValue

        if request.method != .get, let data = request.body {
            urlRequest.httpBody = data
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let group = DispatchGroup()

        var finalResponse: Response?
        var error: Error?

        group.enter()
        let sessionTask = session.dataTask(with: urlRequest) { data, response, err in
            defer { group.leave() }
            guard let urlResponse = response as? HTTPURLResponse,
                let headers = urlResponse.allHeaderFields as? [String: String]
                else {
                    error = err
                    return
            }

            finalResponse = Response.init(statusCode: urlResponse.statusCode,
                                          headers: headers,
                                          body: data)
        }
        sessionTask.resume()

        guard case .success = group.wait(timeout: .now() + request.timeout),
            let response = finalResponse else {
                guard let err = error else {
                    throw StitchError.serviceError(
                        withMessage: "no response from server",
                        withServiceErrorCode: .unknown
                    )
                }

                throw err
        }

        return (response, sessionTask)
    }

    private lazy var opQueue: OperationQueue = {
        let opQueue = OperationQueue()
        opQueue.underlyingQueue = underlyingQueue
        return opQueue
    }()

    private let underlyingQueue = DispatchQueue.init(label: "change-streams", qos: .userInitiated)

    public func doStream(
        request: Request,
        delegate: SSEStreamDelegate? = nil
    ) throws -> (RawSSEStream, URLSessionDataTask) {
        guard let url = URL(string: request.url) else {
            throw StitchError.clientError(withClientErrorCode: .missingURL)
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = TimeInterval(30)
        sessionConfig.timeoutIntervalForResource = TimeInterval(INT_MAX)
        let additionalheaders = [Headers.contentType.nonCanonical(): "text/event-stream",
                                 Headers.cacheControl.nonCanonical(): "no-cache",
                                 Headers.accept.nonCanonical(): "text/event-stream"]
        sessionConfig.httpAdditionalHeaders = additionalheaders
        let sseStream = FoundationHTTPSSEStream(delegate)
        let session = URLSession.init(configuration: sessionConfig,
                                      delegate: sseStream.dataDelegate,
                                      delegateQueue: opQueue)

        let sessionTask = session.dataTask(with: url)
        sessionTask.resume()

        sseStream.state = .opening
        return (sseStream, sessionTask)
    }
}
