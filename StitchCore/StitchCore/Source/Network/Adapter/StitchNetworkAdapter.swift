import Foundation
import ExtendedJson
import StitchLogger
import PromiseKit
import PMKFoundation

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

        return firstly {
            defaultSession.dataTask(.promise, with: request)
        }.flatMap {
            return (($0.response as? HTTPURLResponse)?.statusCode ?? 500, $0.data)
        }
    }

    public func cancelAllRequests() {

    }

    public init() {}
}
