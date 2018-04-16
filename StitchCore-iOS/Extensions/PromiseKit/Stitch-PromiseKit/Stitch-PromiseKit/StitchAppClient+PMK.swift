import Foundation
import StitchCore_iOS
import PromiseKit
import ExtendedJSON

extension StitchAppClient {
    /**
     * Calls the MongoDB Stitch function with the provided name and arguments.
     *
     * - parameters:
     *     - withName: The name of the Stitch function to be called.
     *     - withArgs: The `BSONArray` of arguments to be provided to the function.
     *     - completionHandler: The completion handler to call when the function call is complete.
     *                          This handler is executed on a non-main global `DispatchQueue`.
     *     - result: The result of the function call as an `Any`, or `nil` if the function call failed.
     *     - error: An error object that indicates why the function call failed, or `nil` if the function call was
     *              successful.
     *
     */
    func callFunction(withName name: String, withArgs args: BSONArray) -> Promise<Any> {
        return Promise {
            self.callFunction(withName: name, withArgs: args, adapter($0))
        }
    }
}
