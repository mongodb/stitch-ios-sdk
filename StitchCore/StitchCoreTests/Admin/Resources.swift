@testable import StitchCore
import PromiseKit

/// Any endpoint that can be described with basic
/// CRUD operations
internal protocol Resource {
    /// absolute url to this endpoint
    var url: String { get }
    /// stitch http client for making requests
    var httpClient: StitchHTTPClient { get }
}

/// Base implementation of Resource Protocol
internal class BasicResource: Resource {
    var url: String
    var httpClient: StitchHTTPClient

    init(httpClient: StitchHTTPClient, url: String) {
        self.httpClient = httpClient
        self.url = url
    }
}

/// Adds an endpoint method that GETs some list
internal protocol Listable: Resource { associatedtype Model: Decodable }
extension Listable {
    public func list() -> Promise<[Model]> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            }.flatMap {
                return try JSONDecoder().decode([Model].self,
                                                from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}

/// Adds an endpoint method that GETs some id
internal protocol Gettable: Resource { associatedtype Model: Decodable }
extension Gettable {
    public func get() -> Promise<Model> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            }.flatMap {
                return try JSONDecoder().decode(Model.self,
                                                from: JSONSerialization.data(withJSONObject: $0))
        }
    }
}

/// Adds an endpoint method that DELETEs some id
internal protocol Removable: Resource {}
extension Removable {
    public func remove() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = self.url
            $0.method = .delete
        }
    }
}

/// Adds an endpoint method that POSTs new data
internal protocol Creatable: Resource {
    associatedtype CreatorModel: Encodable
    associatedtype Model: Decodable
}
extension Creatable {
    public func create(data: CreatorModel) -> Promise<Model> {
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

/// Adds an endpoint method that PUTs some data
internal protocol Updatable: Resource { associatedtype Model: Codable }
extension Updatable {
    public func update(data: Model) -> Promise<Model> {
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

/// Adds an endpoint that enables a given resource
internal protocol Enablable: Resource {}
extension Enablable {
    public func enable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/enable"
            $0.method = .put
        }
    }
}

/// Adds an endpoint that disables a given resource
internal protocol Disablable: Resource {}
extension Disablable {
    public func disable() -> Promise<Any> {
        return self.httpClient.doRequest {
            $0.endpoint = "\(self.url)/disable"
            $0.method = .put
        }
    }
}

/// Resource that lists the current groupId's applications
internal final class Apps: BasicResource, Listable {
    typealias Model = AppResponse

    /// Resource for specific application. Can fetch users, authProviders,
    /// userRegistrations, and services of this application
    internal final class App: BasicResource, Gettable, Removable {
        typealias Model = AppResponse

        /// Resource for listing the auth providers of an application
        internal final class AuthProviders: BasicResource, Listable, Creatable {
            typealias Model = AuthProviderResponse
            typealias CreatorModel = ProviderConfigs

            /// Resource for a specific auth provider of an application
            internal final class AuthProvider: BasicResource, Gettable, Updatable, Removable, Enablable, Disablable {
                typealias Model = AuthProviderResponse
                typealias CreatorModel = ProviderConfigs
            }
        }

        /// Resource for user registrations of an application
        internal final class UserRegistrations: BasicResource {}

        /// Resource for a list of users of an application
        internal final class Users: BasicResource, Listable, Creatable {
            typealias Model = UserResponse
            typealias CreatorModel = UserCreator

            /// Resource for a single user of an application
            internal final class User: BasicResource, Gettable, Removable {
                typealias Model = UserResponse
            }
        }

        /// Resource for listing services of an application
        internal final class Services: BasicResource, Listable, Creatable {
            typealias Model = ServiceResponse
            typealias CreatorModel = ServiceConfigs

            /// Resource for a specific service of an application. Can fetch rules
            /// of the service
            internal final class Service: BasicResource, Gettable, Removable {
                typealias Model = ServiceResponse

                /// Resource for listing the rules of a service
                internal final class Rules: BasicResource, Listable, Creatable {
                    typealias Model = RuleResponse
                    typealias CreatorModel = RuleCreator

                    /// Resource for a specific rule of a service
                    internal final class Rule: BasicResource, Gettable, Removable {
                        typealias Model = RuleResponse
                    }
                }

                lazy var rules = Rules.init(httpClient: self.httpClient,
                                                    url: "\(self.url)/rules")
            }
        }

        lazy var authProviders: AuthProviders =
            AuthProviders.init(httpClient: self.httpClient,
                                       url: "\(self.url)/auth_providers")

        lazy var users: Users =
            Users.init(httpClient: self.httpClient,
                               url: "\(self.url)/users")

        lazy var userRegistrations: UserRegistrations =
            UserRegistrations.init(httpClient: self.httpClient,
                                           url: "\(self.url)/user_registrations")

        lazy var services: Services =
            Services.init(httpClient: self.httpClient,
                                  url: "\(self.url)/services")
    }
}
