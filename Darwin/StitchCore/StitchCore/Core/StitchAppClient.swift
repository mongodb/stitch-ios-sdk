import MongoSwift
import StitchCoreSDK
import Foundation

/**
 * The fundamental set of methods for communicating with a MongoDB Stitch application.
 * Contains methods for executing Stitch functions and retrieving clients for Stitch services,
 * contains a `StitchAuth` object to manage the authentication state of the client, and contains a
 * `StitchPush` object to register the current user for push notifications. An implementation can be instantiated using
 * the `Stitch` utility class.
 */
public protocol StitchAppClient {

    // MARK: Authentication

    /**
     * The StitchAuth object representing the authentication state of this client. Includes methods for logging in
     * and logging out.
     *
     * - important: Authentication state can be persisted beyond the lifetime of an application.
     *              A StitchAppClient retrieved from the `Stitch` singleton may or may not be
     *              authenticated when first initialized.
     */
    var auth: StitchAuth { get }

    // MARK: Push Notifications

    /**
     * The push notifications component of the app. This is used for registering the currently signed in user for push
     * notifications.
     */
    var push: StitchPush { get }

    // MARK: Services

    /**
     * Retrieves a general-purpose service client for the Stitch service
     * associated with the specified name. Use this for services which do not
     * have a well-defined interface in the SDK.
     *
     * - parameters:
     *     - withServiceName: The name of the desired service in MongoDB Stitch.
     */
    func serviceClient(withServiceName serviceName: String) -> StitchServiceClient

    /**
     * Retrieves the service client for the Stitch service associated with the specified name and factory.
     *
     * - parameters:
     *     - fromFactory: An `AnyNamedServiceClientFactory` object which contains a `NamedServiceClientFactory`
     *                    class which will provide the client for this service. Each available service has a static
     *                    factory which can be used for this method.
     *
     *     - withName: The name of the service as defined in the MongoDB Stitch application.
     * - returns: a service client whose type is determined by the `T` type parameter of the
     *            `AnyNamedServiceClientFactory` passed in the `fromFactory` parameter.
     */
    func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>, withName serviceName: String) -> T

    /**
     * Retrieves the service client for the Stitch service associated with the specificed factory.
     *
     * - parameters:
     *     - fromFactory: An `AnyNamedServiceClientFactory` object which contains a `NamedServiceClientFactory`
     *                    class which will provide the client for this service. Each available service has a static
     *                    factory which can be used for this method.
     * - returns: a service client whose type is determined by the `T` type parameter of the
     *            `AnyNamedServiceClientFactory` passed in the `fromFactory` parameter.
     */
    func serviceClient<T>(fromFactory factory: AnyNamedServiceClientFactory<T>) -> T

    /**
     * Retrieves the service client for the Stitch service associated with the service type with the specified factory.
     *
     * - parameters:
     *     - fromFactory: An `AnyThrowingServiceClientFactory` object which contains a `ThrowingServiceClientFactory`
     *                    class which will provide the client for this service. Each available service has a static
     *                    factory which can be used for this method.
     * - returns: a service client whose type is determined by the `T` type parameter of the
     *            `AnyThrowingServiceClientFactory` passed in the `fromFactory` parameter.
     */
    func serviceClient<T>(fromFactory factory: AnyThrowingServiceClientFactory<T>) throws -> T

    // MARK: Functions

    // swiftlint:disable line_length

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments, and decodes the result of the function
     * into a `Decodable` type as specified by the `T` type parameter.
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `T` representing the decoded result of the
     *                          function call.
     *
     */
    func callFunction<T: Decodable>(withName name: String, withArgs args: [BsonValue], _ completionHandler: @escaping (StitchResult<T>) -> Void)

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments, ignoring the result of the function.
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     */
    func callFunction(withName name: String, withArgs args: [BsonValue], _ completionHandler: @escaping (StitchResult<Void>) -> Void)

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments, and decodes the result of the function
     * into a `Decodable` type as specified by the `T` type parameter. Also accepts a timeout. Use this for functions
     * that may run longer than the client-wide default timeout (15 seconds by default).
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - withRequestTimeout: The number of seconds the client should wait for a response from the server before
     *                           failing with an error.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will contain a `T` representing the decoded result of the
     *                          function call.
     */
    func callFunction<T: Decodable>(withName name: String, withArgs args: [BsonValue], withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<T>) -> Void)

    /**
     * Calls the MongoDB Stitch function with the provided name and arguments, ignoring the result of the function.
     * Also accepts a timeout. Use this for functions that may run longer than the client-wide default timeout (15
     * seconds by default).
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - withRequestTimeout: The number of seconds the client should wait for a response from the server before
     *                           failing with an error.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *
     */
    func callFunction(withName name: String, withArgs args: [BsonValue], withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<Void>) -> Void)
    // swiftlint:enable line_length
}
