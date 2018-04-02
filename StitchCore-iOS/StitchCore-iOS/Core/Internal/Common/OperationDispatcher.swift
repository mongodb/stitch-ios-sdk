import Foundation

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
    internal init(withDispatchQueue queue: DispatchQueue = DispatchQueue.global()) {
        self.queue = queue
    }

    /**
     * Runs an arbitrary block of code that returns a value, and runs the provided completion handler
     * after the block is run. The completion handler accepts the optional result of the function and
     * an optional `Error` object which will be non-nil if the code block threw an error.
     */
    internal func run<ResultType>(withCompletionHandler completionHandler: @escaping (ResultType?, Error?) -> Void,
                                  _ function: @escaping () throws -> ResultType) {
        queue.async {
            do {
                let result = try function()
                completionHandler(result, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    /**
     * Runs an arbitrary block of void-returning code, and runs the provided completion handler
     * after the block is run. The completion handler accepts an optional `Error` object which
     * will be non-nil if the code block threw an error.
     */
    internal func run(withCompletionHandler completionHandler: @escaping (Error?) -> Void,
                      _ function: @escaping () throws -> Void) {
        queue.async {
            do {
                try function()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
