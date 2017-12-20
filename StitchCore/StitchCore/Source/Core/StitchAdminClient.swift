//
//  StitchAdminClient.swift
//  StitchCore
//
//  Created by Jason Flax on 12/18/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import PromiseKit

private protocol View {
    var url: String { get }
    var httpClient: StitchHTTPClient { get }
}
private protocol List: View { associatedtype Model: Codable }
extension List {
    func list() -> Promise<[Model]> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
        }.flatMap {
            return try JSONDecoder().decode([Model].self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
private protocol Get: View { associatedtype Model: Codable }
extension Get {
    private func get() -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
private protocol Remove: View { associatedtype Model: Codable }
extension Remove {
    func remove() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .delete
        }
    }
}
private protocol Create: View { associatedtype Model: Codable }
extension Create {
    func create(data: Model) -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .post
            try $0.encode(withData: data)
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}
private protocol Update: View { associatedtype Model: Codable }
extension Update {
    func update(data: Model) -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .put
            try $0.encode(withData: data)
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}



public struct ValueView: View, Get, Remove, Update {
    typealias Model = Value

    fileprivate let httpClient: StitchHTTPClient
    fileprivate let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     valueUrl: String) {
        self.httpClient = httpClient
        self.url = valueUrl
    }
}

public struct ValuesView: View, List, Create {
    typealias Model = Value

    fileprivate let httpClient: StitchHTTPClient
    fileprivate let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     appUrl: String) {
        self.httpClient = httpClient
        self.url = appUrl
    }

    func value(withId id: String) -> ValueView {
        return ValueView.init(httpClient: self.httpClient, valueUrl: "\(url)/\(id)")
    }
}

public struct AppView: View, Get, Remove {
    typealias Model = App

    fileprivate let httpClient: StitchHTTPClient
    fileprivate let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     appUrl: String) {
        self.httpClient = httpClient
        self.url = appUrl
    }

    func values() -> ValuesView {
        return ValuesView.init(httpClient: httpClient, appUrl: "\(url)/values")
    }
}

public struct AppsView: View, List {
    typealias Model = App

    let httpClient: StitchHTTPClient
    let url: String

    fileprivate init(httpClient: StitchHTTPClient,
                     groupUrl: String) {
        self.httpClient = httpClient
        self.url = groupUrl
    }

    func create(data: App, defaults: Bool = false) -> Promise<App> {
        return httpClient.doRequest {
            $0.endpoint = "\(self.url)?defaults=\(defaults)"
            $0.method = .post
            try $0.encode(withData: data)
        }.flatMap {
            return try JSONDecoder().decode(Model.self,
                                            from: JSONSerialization.data(withJSONObject: $0))
        }
    }

    func app(withAppId appId: String) -> AppView {
        return AppView.init(httpClient: self.httpClient, appUrl: "\(url)/\(appId)")
    }
}

struct AuthProviderOutput: Codable {

}
struct User: Codable {

}
struct PushNotification: Codable {

}
struct IncomingWebhook: Codable {

}
struct Rule: Codable {

}
struct ServiceInput: Codable {

}
struct Value: Codable {

}
struct App: Codable {

}

public class StitchAdminClient {
    let baseUrl: String
    let httpClient: StitchHTTPClient

    init(baseUrl: String) {
        self.baseUrl = baseUrl
        self.httpClient = StitchHTTPClient.init(baseUrl: baseUrl, networkAdapter: StitchNetworkAdapter())
    }

    func apps(withGroupId groupId: String) -> AppsView {
        return AppsView.init(httpClient: httpClient, groupUrl: "/groups/\(groupId)/apps")
    }
}
