import Foundation
import MongoSwift

/**
 * A basic implementation of the `Transport` protocol using the `URLSession.dataTask` method in the Foundation library.
 */
public final class FoundationHTTPTransport: Transport {

    /**
     * Empty public initializer to make initialization of this Transport available outside of this module.
     */
    public init() {
    }

    /**
     * The round trip functionality for this Transport, which uses `URLSession.dataTask`.
     */
    public func roundTrip(request: Request) throws -> Response {
        guard let url = URL(string: request.url) else {
            throw StitchError.clientError(withClientErrorCode: .missingURL)
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = request.timeout

        let session = URLSession(configuration: sessionConfig)

        var urlRequest = URLRequest(url: url)

        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.rawValue

        if request.method != .get, let data = request.body {
            urlRequest.httpBody = data
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let sema = DispatchSemaphore(value: 0)

        var finalResponse: Response?
        var error: Error?

        session.dataTask(with: urlRequest) { data, response, err in
            defer { sema.signal() }
            guard let urlResponse = response as? HTTPURLResponse,
                let headers = urlResponse.allHeaderFields as? [String: String]
                else {
                error = err
                return
            }

            finalResponse = Response.init(statusCode: urlResponse.statusCode,
                                          headers: headers,
                                          body: data)
        }.resume()

        sema.wait()

        guard let response = finalResponse else {
            guard let err = error else {
                throw StitchError.serviceError(
                    withMessage: "no response from server",
                    withServiceErrorCode: .unknown
                )
            }

            throw err
        }

        return response
    }

    private class FoundationStreamDelegate: NSObject, URLSessionTaskDelegate {
        private let semaphore: DispatchSemaphore
        private var response: Response?
        private var error: Error?
        public var inputStream: InputStream?

        init(semaphore: DispatchSemaphore) {
            self.semaphore = semaphore
        }
        
        public func urlSession(_ session: URLSession,
                               task: URLSessionTask,
                               needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
            guard let urlResponse = task.response as? HTTPURLResponse,
                let headers = urlResponse.allHeaderFields as? [String: String]
                else {
                    self.error = task.error
                    return
            }

            self.response = Response.init(statusCode: urlResponse.statusCode,
                                          headers: headers,
                                          body: nil)
            var inStream: InputStream? = nil
            var outStream: OutputStream? = nil
            Stream.getBoundStreams(withBufferSize: 4096,
                                   inputStream: &inStream,
                                   outputStream: &outStream)
            completionHandler(inStream)
            self.inputStream = inStream
            self.semaphore.signal()
        }
    }

    public func stream(request: Request) throws -> EventStream {
        guard let url = URL(string: request.url) else {
            throw StitchError.clientError(withClientErrorCode: .missingURL)
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForResource = request.timeout

        let sema = DispatchSemaphore(value: 0)
        let delegate = FoundationStreamDelegate(semaphore: sema)
        let session = URLSession.init(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        var urlRequest = URLRequest(url: url)

        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.rawValue

        if request.method != .get, let data = request.body {
            urlRequest.httpBody = data
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        session.uploadTask(withStreamedRequest: urlRequest).resume()
        sema.wait()
        return FoundationHTTPEventStream.init(inputStream: delegate.inputStream!)
    }
}
