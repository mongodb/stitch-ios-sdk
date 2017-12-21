import Foundation
import ExtendedJson
import StitchLogger
import PromiseKit

public class StitchNetworkAdapter: NetworkAdapter {
    private var tasks: [URLSessionDataTask] = []

    public func requestWithJsonEncoding(url: String,
                                        method: NAHTTPMethod,
                                        data: Data?,
                                        headers: [String: String]? = [:]) -> Promise<(Int, Data?)> {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let defaultSession = URLSession(configuration: config)

        guard let url = URL(string: url) else {
            return Promise.init(error: StitchError.illegalAction(message: "bad url"))
        }

        var contentHeaders = headers ?? [:]
        contentHeaders["Content-Type"] = "application/json"

        var request = URLRequest(url: url)

        request.allHTTPHeaderFields = contentHeaders
        request.httpMethod = method.rawValue

        if method != .get, let data = data {
            request.httpBody = data
        }

        return Promise { fulfill, reject in
            defaultSession.dataTask(with: request) { data, response, error in
                guard let resp = response as? HTTPURLResponse else {
                    if let error = error {
                        reject(error)
                    }

                    return
                }

                fulfill((resp.statusCode, data))
            }.resume()
        }
    }

    public func cancelAllRequests() {

    }

    public init() {}
}
