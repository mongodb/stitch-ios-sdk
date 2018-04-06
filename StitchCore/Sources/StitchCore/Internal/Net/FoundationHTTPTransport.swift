import Foundation

/**
 * A basic implementation of the `Transport` protocol using the `URLSession.dataTask` method in the Foundation library.
 */
public final class FoundationHTTPTransport: Transport {

    /**
     * Empty public initializer to make initialization of this Transport available outside of this module.
     */
    public init() { }

    /**
     * The round trip functionality for this Transport, which uses `URLSession.dataTask`.
     */
    public func roundTrip(request: Request) throws -> Response {
        guard let url = URL(string: request.url) else {
            throw StitchError.clientError(withClientErrorCode: .missingURL)
        }

        let defaultSession = URLSession(configuration: URLSessionConfiguration.default)

        var contentHeaders = request.headers
        contentHeaders[Headers.contentType.rawValue] =
            ContentTypes.applicationJson.rawValue

        var urlRequest = URLRequest(url: url)

        urlRequest.allHTTPHeaderFields = contentHeaders
        urlRequest.httpMethod = request.method.rawValue

        if request.method != .get, let data = request.body {
            urlRequest.httpBody = data
        }

        let sema = DispatchSemaphore(value: 0)

        var finalResponse: Response?
        var error: Error?

        defaultSession.dataTask(with: urlRequest) { data, response, err in
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
                throw StitchError.serviceError(withMessage: nil, withServiceErrorCode: .unknown)
            }

            throw err
        }

        return response
    }
}
