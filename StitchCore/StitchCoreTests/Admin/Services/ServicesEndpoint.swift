import Foundation
@testable import StitchCore

internal struct ServiceView: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id", name, type
    }
    
    let id, name, type: String
}

public final class ServiceEndpoint: Endpoint, Get, Remove {
    var url: String
    var httpClient: StitchHTTPClient
    typealias Model = ServiceView

    init(httpClient: StitchHTTPClient, serviceUrl: String) {
        self.url = serviceUrl
        self.httpClient = httpClient
    }

    lazy var rules = RulesEndpoint.init(httpClient: self.httpClient,
                                        rulesUrl: "\(self.url)/rules")
}

public final class ServicesEndpoint: Endpoint, List, Create {
    var url: String
    var httpClient: StitchHTTPClient

    typealias Model = ServiceView
    typealias CreatorModel = ServiceConfigs

    init(httpClient: StitchHTTPClient, servicesUrl: String) {
        self.url = servicesUrl
        self.httpClient = httpClient
    }

    func service(withId id: String) -> ServiceEndpoint {
        return ServiceEndpoint.init(httpClient: self.httpClient,
                                    serviceUrl: "\(self.url)/\(id)")
    }
}
