//
//  AuthProvidersEndpoints.swift
//  StitchCore
//
//  Created by Jason Flax on 2/2/18.
//  Copyright © 2018 MongoDB. All rights reserved.
//

import Foundation

struct AuthProviderCreator: Encodable {
    let type: String
    let config: [String: String]
}

public struct AuthProviderView: Codable {
    private enum CodingKeys: String, CodingKey {
        case id = "_id", disabled, name, type
    }

    public let id: String
    public let disabled: Bool
    public let name: String
    public let type: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.disabled = try container.decode(Int.self, forKey: .disabled) == 0 ? false : true
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
    }
}

public final class AuthProviderEndpoint: Endpoint, Get, Update, Remove, Enable, Disable {
    typealias Model = AuthProviderView
    typealias CreatorModel = AuthProviderCreator

    internal let httpClient: StitchHTTPClient
    internal let url: String

    internal init(httpClient: StitchHTTPClient,
                  authProviderUrl: String) {
        self.httpClient = httpClient
        self.url = authProviderUrl
    }
}

public final class AuthProvidersEndpoint: Endpoint, List, Create {
    typealias Model = AuthProviderView
    typealias CreatorModel = AuthProviderCreator

    internal let httpClient: StitchHTTPClient
    internal let url: String

    internal init(httpClient: StitchHTTPClient,
                  authProvidersUrl: String) {
        self.httpClient = httpClient
        self.url = authProvidersUrl
    }

    func authProvider(providerId: String) -> AuthProviderEndpoint {
        return AuthProviderEndpoint.init(httpClient: self.httpClient,
                                         authProviderUrl: "\(url)/\(providerId)")
    }
}
