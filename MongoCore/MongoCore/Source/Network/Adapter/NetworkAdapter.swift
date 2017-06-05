//
//  NetworkAdapter.swift
//  MongoCore
//
//  Created by Yanai Rozenberg on 24/05/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

public protocol NetworkAdapter {
    func requestWithArray(url: String, method: NAHTTPMethod, parameters: [[String : Any]]?, headers: [String : String]?) ->  BaasTask<Any>
    func requestWithJsonEncoding(url: String, method: NAHTTPMethod, parameters: [String : Any]?, headers: [String : String]?) ->  BaasTask<Any>
    func cancelAllRequests()
    
}

public enum NAHTTPMethod: String {
    case options = "OPTIONS"
    case get     = "GET"
    case head    = "HEAD"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case trace   = "TRACE"
    case connect = "CONNECT"
}
