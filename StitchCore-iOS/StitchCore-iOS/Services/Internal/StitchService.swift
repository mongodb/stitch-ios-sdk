import BSON
import StitchCore

/**
 * A protocol representing a MongoDB Stitch service, with methods for executing functions on that service.
 * A class implementing this protocol for a service with known functions and return values may implement
 * concrete methods that use these methods internally.
 */
public protocol StitchService: CoreStitchService {

    // swiftlint:disable line_length

    /**
     * Calls the function for this service with the provided name and arguments.
     *
     * - parameters:
     *     - withName: The name of the function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - result: The result of the function call as an `Any`, or `nil` if the function call failed.
     *     - error: An error object that indicates why the function call failed, or `nil` if the function call was
     *              successful.
     *
     */
    func callFunction<T: Codable>(withName name: String,
                                  withArgs args: [BsonValue],
                                  _ completionHandler: @escaping (_ result: T?, _ error: Error?) -> Void)
    // swiftlint:enable line_length
}
