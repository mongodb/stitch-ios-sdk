import Foundation
import ExtendedJson
import StitchLogger

public class StitchNetworkAdapter: NetworkAdapter {
    private var tasks: [URLSessionDataTask] = []

    public func requestWithJsonEncoding(url: String,
                                        method: NAHTTPMethod,
                                        data: Data?,
                                        headers: [String: String]? = [:]) -> StitchTask<(Int, Data?)> {
        let task = StitchTask<(Int, Data?)>()

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let defaultSession = URLSession(configuration: config)

        guard let url = URL(string: url) else {
            task.result = .failure(StitchError.illegalAction(message: "bad url"))
            return task
        }

        var contentHeaders = headers ?? [:]
        contentHeaders["Content-Type"] = "application/json"

        var request = URLRequest(url: url)

        request.allHTTPHeaderFields = contentHeaders
        request.httpMethod = method.rawValue

        if method != .get, let data = data {
            request.httpBody = data
        }

        let dataTask = defaultSession.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            if let error = error {
                printLog(.error, text: error.localizedDescription)
                task.result = .failure(error)
                return
            }

            task.result = .success(((response as? HTTPURLResponse)?.statusCode ?? 500, data))
        }

        dataTask.resume()
        tasks.append(dataTask)
        return task
    }

    public func cancelAllRequests() {

    }

    public init() {}
}
