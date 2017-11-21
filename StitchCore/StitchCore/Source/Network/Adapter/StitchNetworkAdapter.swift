//
//  StitchNetworkAdapter.swift
//  StitchCore
//
//  Created by Jason Flax on 10/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import ExtendedJson
import StitchLogger

public class StitchNetworkAdapter: NetworkAdapter {
    private var tasks: [URLSessionDataTask] = []

    public func requestWithJsonEncoding<T>(url: String,
                                           method: NAHTTPMethod,
                                           parameters: T?,
                                           headers: [String: String]? = [:]) -> StitchTask<Data?> where T: Encodable {
        let task = StitchTask<Data?>()

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let defaultSession = URLSession(configuration: config)

        guard let url = URL(string: url) else {
            printLog(.error, text: "bad url")
            task.result = .failure(StitchError.illegalAction(message: "bad url"))
            return task
        }

        var contentHeaders = headers ?? [:]
        contentHeaders["Content-Type"] = "application/json"

        var request = URLRequest(url: url)

        request.allHTTPHeaderFields = contentHeaders
        request.httpMethod = method.rawValue

        if method != .get, let parameters = parameters {
            guard let jsonData = try? JSONEncoder().encode(parameters) else {
                printLog(.error, text: "bad json")
                task.result = .failure(StitchError.illegalAction(message: "bad json"))
                return task
            }

            printLog(.debug, text: String(data: jsonData, encoding: .utf8)!)
            request.httpBody = jsonData
        }

        printLog(.debug, text: request.url)
        printLog(.debug, text: request.httpMethod)
        printLog(.debug, text: request.allHTTPHeaderFields)

        let dataTask = defaultSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                printLog(.error, text: error.localizedDescription)
                task.result = .failure(error)
                return
            }

            printLog(.debug, text: response)

            if let data = data {
                printLog(.debug, text: String(data: data, encoding: .utf8))
            }
            task.result = .success(data)
        }

        dataTask.resume()
        tasks.append(dataTask)
        return task
    }

    public func cancelAllRequests() {

    }

    public init() {}
}
