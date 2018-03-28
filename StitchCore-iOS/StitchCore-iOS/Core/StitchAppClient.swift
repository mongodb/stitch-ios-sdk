import ExtendedJSON

/**
 * The fundamental set of methods for communicating with a MongoDB Stitch application.
 * Contains methods for executing Stitch functions and retrieving clients for Stitch services,
 * and contains a StitchAuth object to manage the authentication state of the client. An
 * implementation can be instantiated using the `Stitch` utility class.
 */
public protocol StitchAppClient {
    /**
     * The StitchAuth object representing the authentication state of this client.
     *
     * - important: Authentication state can be persisted beyond the lifetime of an application.
     *              A StitchAppClient retrieved from the `Stitch` singleton may or may not be
     *              authenticated when first initialized.
     */
    var auth: StitchAuth { get }

    /**
     * Retrieves the service client associated with the Stitch service with the specified name and type.
     *
     * - parameters:
     *     - forProvider: An `AnyNamedServiceClientProvider` object which contains a `NamedServiceClientProvider`
     *                    class which will provide the client for this service.
     *     - withName: The name of the service as defined in the MongoDB Stitch application.
     * - returns: a service client whose type is determined by the `T` type parameter of the `AnyNamedServiceClientProvider`
     *            passed in the `forProvider` parameter.
     */
    func serviceClient<T>(forService provider: AnyNamedServiceClientProvider<T>,
                          withName serviceName: String) -> T

    /**
     * Retrieves the service client associated with the service type specified in the argument.
     *
     * - parameters:
     *     - forProvider: An `AnyServiceClientProvider` object which contains a `ServiceClientProvider`
     *                    class which will provide the client for this service.
     * - returns: a service client whose type is determined by the `T` type parameter of the `AnyServiceClientProvider`
     *            passed in the `forProvider` parameter.
     */
    func serviceClient<T>(forService provider: AnyServiceClientProvider<T>) -> T
    
    /**
     * Calls the MongoDB Stitch function with the provided name and arguments.
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - result: The result of the function call as an `Any`, or `nil` if the function call failed.
     *     - error: An error object that indicates why the function call failed, or `nil` if the function call was successful.
     *
     */
    func callFunction(withName name: String,
                      withArgs args: BSONArray,
                      _ completionHandler: @escaping (_ result: Any?, _ error: Error?) -> Void)
}
