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
        let defaultSession = URLSession(configuration: .default)

        guard let url = URL(string: url) else {
            task.result = .failure(StitchError.illegalAction(message: "bad url"))
            return task
        }

        var contentHeaders = headers ?? [:]
        contentHeaders["Content-Type"] = "application/json"
        var request = URLRequest(url: url)

        request.allHTTPHeaderFields = contentHeaders
        request.httpMethod = method.rawValue

        if let parameters = parameters {
            guard let jsonData = try? JSONEncoder().encode(parameters) else {
                task.result = .failure(StitchError.illegalAction(message: "bad json"))
                return task
            }

            printLog(.debug, text: String(data: jsonData, encoding: .utf8)!)
            request.httpBody = jsonData
        }

        printLog(.debug, text: request.allHTTPHeaderFields)
        let dataTask = defaultSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                task.result = .failure(error)
                return
            }

            printLog(.debug, text: response)

            if let data = data {
                printLazy(.debug, text: { try? JSONSerialization.jsonObject(with: data, options: .allowFragments) })
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
