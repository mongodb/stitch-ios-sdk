import Foundation
import StitchCoreSDK

/**
 * A class holding a `DispatchQueue` that can run arbitrary code blocks with arbitrary completion handlers.
 */
public class OperationDispatcher {
    /**
     * The internal `DispatchQueue` on which the code will be scheduled and executed.
     */
    internal let queue: DispatchQueue

    /**
     * Initializes the dispatcher with the provided `DispatchQueue`, or the default
     * `DispatchQueue` by default.
     */
    public init(withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) {
        self.queue = queue
    }

    /**
     * Runs an arbitrary block of code that returns a value, and runs the provided completion handler
     * after the block is run. The completion handler accepts the optional result of the function and
     * an optional `Error` object which will be non-nil if the code block threw an error.
     */
    public func run<ResultType>(withCompletionHandler completionHandler: @escaping (StitchResult<ResultType>) -> Void,
                                _ function: @escaping () throws -> ResultType) {
        queue.async {
            do {
                let result = try function()
                completionHandler(StitchResult<ResultType>.success(result: result))
            } catch {
                if let stitchError = error as? StitchError {
                    completionHandler(StitchResult<ResultType>.failure(error: stitchError))
                } else {
                    // this should not happen since StitchCoreSDK wraps all errors in a `StitchError`, but if there is
                    // a bug and an error is not wrapped, we will wrap it here with an unknown error code.
                    completionHandler(StitchResult<ResultType>.failure(
                        error: StitchError.requestError(
                            withError: error, withRequestErrorCode: .unknownError)
                        )
                    )
                }
            }
        }
    }
}
