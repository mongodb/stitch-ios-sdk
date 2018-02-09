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
internal final class AppsResource: BasicResource, Listable {
    typealias Model = AppView

    /// Resource for specific application. Can fetch users, authProviders,
    /// userRegistrations, and services of this application
    internal final class AppResource: BasicResource, Gettable, Removable {
        typealias Model = AppView

        /// Resource for listing the auth providers of an application
        internal final class AuthProvidersResource: BasicResource, Listable, Creatable {
            typealias Model = AuthProviderView
            typealias CreatorModel = ProviderConfigs

            /// Resource for a specific auth provider of an application
            internal final class AuthProviderResource: BasicResource, Gettable, Updatable, Removable, Enablable, Disablable {
                typealias Model = AuthProviderView
                typealias CreatorModel = ProviderConfigs
            }
        }

        /// Resource for user registrations of an application
        internal final class UserRegistrationsResource: BasicResource {}

        /// Resource for a list of users of an application
        internal final class UsersResource: BasicResource, Listable, Creatable {
            typealias Model = UserView
            typealias CreatorModel = UserCreator

            /// Resource for a single user of an application
            internal final class UserResource: BasicResource, Gettable, Removable {
                typealias Model = UserView
            }
        }

        /// Resource for listing services of an application
        internal final class ServicesResource: BasicResource, Listable, Creatable {
            typealias Model = ServiceView
            typealias CreatorModel = ServiceConfigs

            /// Resource for a specific service of an application. Can fetch rules
            /// of the service
            internal final class ServiceResource: BasicResource, Gettable, Removable {
                typealias Model = ServiceView

                /// Resource for listing the rules of a service
                internal final class RulesResource: BasicResource, Listable, Creatable {
                    typealias Model = RuleView
                    typealias CreatorModel = Rule

                    /// Resource for a specific rule of a service
                    internal final class RuleResource: BasicResource, Gettable, Removable {
                        typealias Model = RuleView
                    }
                }

                lazy var rules = RulesResource.init(httpClient: self.httpClient,
                                                    url: "\(self.url)/rules")
            }
        }

        lazy var authProviders: AuthProvidersResource =
            AuthProvidersResource.init(httpClient: self.httpClient,
                                       url: "\(self.url)/auth_providers")

        lazy var users: UsersResource =
            UsersResource.init(httpClient: self.httpClient,
                               url: "\(self.url)/users")

        lazy var userRegistrations: UserRegistrationsResource =
            UserRegistrationsResource.init(httpClient: self.httpClient,
                                           url: "\(self.url)/user_registrations")

        lazy var services: ServicesResource =
            ServicesResource.init(httpClient: self.httpClient,
                                  url: "\(self.url)/services")
    }
}
