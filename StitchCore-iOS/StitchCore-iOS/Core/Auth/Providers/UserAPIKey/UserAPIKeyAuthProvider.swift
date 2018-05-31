import Foundation
import StitchCore
import MongoSwift

/**
 * A utility class which contains a property that can be used with `StitchAuth` to retrieve a
 * `UserAPIKeyAuthProviderClient`.
 */
public final class UserAPIKeyAuthProvider {
    /**
     * An `AuthProviderClientFactory` which can be used with `StitchAuth` to retrieve an
     * `UserAPIKeyAuthProviderClient`.
     */
    public static let clientFactory: ClientFactoryImpl
        = ClientFactoryImpl.init()

    /**
     * :nodoc:
     * An implementation of `AuthProviderClientFactory` that produces an
     * `UserAPIKeyAuthProviderClient`.
     */
    public final class ClientFactoryImpl: AuthProviderClientFactory {
        public typealias ClientT = UserAPIKeyAuthProviderClient
        public typealias RequestClientT = StitchAuthRequestClient

        public func client(withRequestClient authRequestClient: StitchAuthRequestClient,
                           withRoutes routes: StitchAuthRoutes,
                           withDispatcher dispatcher: OperationDispatcher) -> ClientT {
            return UserAPIKeyAuthProviderClientImpl.init(
                withAuthRequestClient: authRequestClient,
                withAuthRoutes: routes,
                withDispatcher: dispatcher
            )
        }
    }
}

public protocol UserAPIKeyAuthProviderClient {
    /**
     * Creates a user API key that can be used to authenticate as the current user.
     *
     * - parameters:
     *     - withName: The name of the API key to be created.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func createApiKey(withName name: String, _ completionHandler: @escaping (UserAPIKey?, Error?) -> Void)

    /**
     * Fetches a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to fetch.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func fetchApiKey(withId id: ObjectId, _ completionHandler: @escaping (UserAPIKey?, Error?) -> Void)

    /**
     * Fetches the user API keys associated with the current user.
     *
     * - parameters:
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func fetchApiKeys(_ completionHandler: @escaping ([UserAPIKey]?, Error?) -> Void)

    /**
     * Deletes a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to delete.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func deleteApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void)

    /**
     * Enables a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to enable.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func enableApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void)

    /**
     * Disables a user API key associated with the current user.
     *
     * - parameters:
     *     - withId: The id of the API key to disable.
     *     - completionHandler: The handler to be executed when the request is complete.
     */
    func disableApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void)
}

private class UserAPIKeyAuthProviderClientImpl:
CoreAuthenticatedUserAPIKeyClient, UserAPIKeyAuthProviderClient {
    private let dispatcher: OperationDispatcher

    init(withAuthRequestClient authRequestClient: StitchAuthRequestClient,
         withAuthRoutes authRoutes: StitchAuthRoutes,
         withDispatcher dispatcher: OperationDispatcher) {
        self.dispatcher = dispatcher
        super.init(withAuthRequestClient: authRequestClient,
                   withAuthRoutes: authRoutes)
    }

    func createApiKey(withName name: String, _ completionHandler: @escaping (UserAPIKey?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try super.createApiKey(withName: name)
        }
    }

    func fetchApiKey(withId id: ObjectId, _ completionHandler: @escaping (UserAPIKey?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return  try super.fetchApiKey(withId: id)
        }
    }

    func fetchApiKeys(_ completionHandler: @escaping ([UserAPIKey]?, Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            return try super.fetchApiKeys()
        }
    }

    func deleteApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try super.deleteApiKey(withId: id)
        }
    }

    func enableApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try super.enableApiKey(withId: id)
        }
    }

    func disableApiKey(withId id: ObjectId, _ completionHandler: @escaping (Error?) -> Void) {
        dispatcher.run(withCompletionHandler: completionHandler) {
            try super.disableApiKey(withId: id)
        }
    }
}
