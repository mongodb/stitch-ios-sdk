import Foundation

/// Any endpoint that can be described with basic
/// CRUD operations
public protocol Resource {
    /// path to this endpoint
    var url: String { get }
    /// stitch admin auth for making requests
    var adminAuth: StitchAdminAuth { get }
}

/// Base implementation of Resource Protocol
public class BasicResource: Resource {
    public var url: String
    public var adminAuth: StitchAdminAuth

    init(adminAuth: StitchAdminAuth, url: String) {
        self.adminAuth = adminAuth
        self.url = url
    }
}

/**
 * Throws an error if the provided `Response` has an empty body.
 */
internal func checkEmpty(_ response: Response) throws {
    guard response.body != nil else {
        throw StitchError.serviceError(withMessage: "unexpected empty response", withServiceErrorCode: .unknown)
    }
}

/// Adds an endpoint method that GETs some list
public protocol Listable: Resource { associatedtype Model: Decodable }
extension Listable {
    public func list() throws -> [Model] {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = .get
            $0.path = self.url
        }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)

        return try JSONDecoder().decode([Model].self, from: response.body!)
    }
}

/// Adds an endpoint method that GETs some id
public protocol Gettable: Resource { associatedtype Model: Decodable }
extension Gettable {
    public func get() throws -> Model {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = .get
            $0.path = self.url
        }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(Model.self, from: response.body!)
    }
}

/// Adds an endpoint method that DELETEs some id
public protocol Removable: Resource {}
extension Removable {
    public func remove() throws {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = .delete
            $0.path = self.url
        }.build()

        _ = try adminAuth.doAuthenticatedRequest(req)
    }
}

/// Adds an endpoint method that POSTs new data
public protocol Creatable: Resource {
    associatedtype CreatorModel: Encodable
    associatedtype Model: Decodable
}
extension Creatable {
    public func create(data: CreatorModel) throws -> Model {
        let encodedCreation = try JSONEncoder().encode(data)
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.post
            $0.path = self.url
            $0.body = encodedCreation
        }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(Model.self, from: response.body!)
    }
}

/// Adds an endpoint method that PUTs some data
public protocol Updatable: Resource {
    associatedtype UpdaterModel: Encodable
    associatedtype Model: Decodable
}
extension Updatable {
    public func update(data: UpdaterModel) throws -> Model {
        let encodedUpdate = try JSONEncoder().encode(data)
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.put
            $0.path = self.url
            $0.body = encodedUpdate
            }.build()

        let response = try adminAuth.doAuthenticatedRequest(req)
        try checkEmpty(response)
        return try JSONDecoder().decode(Model.self, from: response.body!)
    }
}

/// Adds an endpoint that enables a given resource
public protocol Enablable: Resource {}
extension Enablable {
    public func enable() throws {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.put
            $0.path = "\(self.url)/enable"
            }.build()

        _ = try adminAuth.doAuthenticatedRequest(req)
    }
}

/// Adds an endpoint that disables a given resource
public protocol Disablable: Resource {}
extension Disablable {
    public func disable() throws {
        let req = try StitchAuthRequestBuilderImpl {
            $0.method = Method.put
            $0.path = "\(self.url)/disable"
            }.build()

       _ = try adminAuth.doAuthenticatedRequest(req)
    }
}

/// Resource that lists the current groupId's applications
//swiftlint:disable nesting
public final class Apps: BasicResource, Listable {
    public typealias Model = AppResponse

    /// Resource for specific application. Can fetch users, authProviders,
    /// userRegistrations, and services of this application
    public final class App: BasicResource, Gettable, Removable {
        public typealias Model = AppResponse

        /// Resource for listing the auth providers of an application
        public final class AuthProviders: BasicResource, Listable, Creatable {
            public typealias Model = AuthProviderResponse
            public typealias CreatorModel = ProviderConfigs

            /// Resource for a specific auth provider of an application
            public final class AuthProvider: BasicResource, Gettable, Updatable, Removable, Enablable, Disablable {
                public typealias Model = AuthProviderResponse
                public typealias CreatorModel = ProviderConfigs
                public typealias UpdaterModel = AuthProviderResponse
            }
        }
        
        /// Resource for listing the functions of an application
        public final class Functions: BasicResource, Listable, Creatable {
            public typealias Model = FunctionResponse
            public typealias CreatorModel = FunctionCreator
            
            /// Resource for a specific function of an application
            public final class Function: BasicResource, Gettable, Updatable, Removable {
                public typealias Model = FunctionResponse
                public typealias CreatorModel = FunctionCreator
                public typealias UpdaterModel = FunctionCreator
            }
        }

        /// Resource for user registrations of an application
        public final class UserRegistrations: BasicResource {}

        /// Resource for a list of users of an application
        public final class Users: BasicResource, Listable, Creatable {
            public typealias Model = UserResponse
            public typealias CreatorModel = UserCreator

            /// Resource for a single user of an application
            public final class User: BasicResource, Gettable, Removable {
                public typealias Model = UserResponse
            }
        }

        /// Resource for listing services of an application
        public final class Services: BasicResource, Listable, Creatable {
            public typealias Model = ServiceResponse
            public typealias CreatorModel = ServiceConfigs

            /// Resource for a specific service of an application. Can fetch rules
            /// of the service
            public final class Service: BasicResource, Gettable, Removable {
                public typealias Model = ServiceResponse

                /// Resource for listing the rules of a service
                public final class Rules: BasicResource, Listable, Creatable {
                    public typealias Model = RuleResponse
                    public typealias CreatorModel = RuleCreator

                    /// Resource for a specific rule of a service
                    public final class Rule: BasicResource, Gettable, Removable {
                        public typealias Model = RuleResponse
                    }
                }

                lazy var rules = Rules.init(adminAuth: self.adminAuth,
                                            url: "\(self.url)/rules")
            }
        }

        public lazy var authProviders: AuthProviders =
            AuthProviders.init(adminAuth: self.adminAuth,
                               url: "\(self.url)/auth_providers")
        
        public lazy var functions: Functions =
            Functions.init(adminAuth: self.adminAuth, url: "\(self.url)/functions")

        public lazy var users: Users =
            Users.init(adminAuth: self.adminAuth,
                       url: "\(self.url)/users")

        public lazy var userRegistrations: UserRegistrations =
            UserRegistrations.init(adminAuth: self.adminAuth,
                                   url: "\(self.url)/user_registrations")

        public lazy var services: Services =
            Services.init(adminAuth: self.adminAuth,
                          url: "\(self.url)/services")
    }
}
//swiftlint:enable nesting
