//
//  StitchNetworkAdapter.swift
//  StitchCore
//
//  Created by Jason Flax on 10/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public class StitchNetworkAdapter: NetworkAdapter {
    private var tasks: [URLSessionDataTask] = []

    public func requestWithJsonEncoding(url: String,
                                        method: NAHTTPMethod,
                                        parameters: Encodable?,
                                        headers: [String: String]?) -> StitchTask<Data?> {
        let task = StitchTask<Data?>()
        let defaultSession = URLSession(configuration: .default)

        guard let url = URL(string: url) else {
            task.result = .failure(StitchError.illegalAction(message: "bad url"))
            return task
        }

        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers

        if let parameters = parameters {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
                task.result = .failure(StitchError.illegalAction(message: "bad json"))
                return task
            }

            request.httpBody = jsonData
        }

        let dataTask = defaultSession.dataTask(with: request) { (data, _, error) in
            if let error = error {
                task.result = .failure(error)
                return
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
