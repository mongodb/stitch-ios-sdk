import Foundation

public final class FoundationHTTPTransport: Transport {

    public init() { }

    public func roundTrip(request: Request) throws -> Response {
        guard let url = URL(string: request.url) else {
            throw StitchErrorCode.invalidURL
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
                throw StitchErrorCode.unknown
            }

            throw err
        }

        return response
    }
}
