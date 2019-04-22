import Foundation
import StitchCoreSDK

/**
 * `StitchResult` holds the result to an asynchronous operation performed against the Stitch server.
 * 
 * When an operation completes successfully, the `StitchResult` holds the result of the operation.
 * When the operation fails, the `StitchResult` contains a `StitchError` object describing
 * the reason for the failure.
 */
public enum StitchResult<T> {
    /**
     * A successful operation, containing the result of the operation.
     */
    case success(result: T)

    /**
     * A failed operation, with an error describing the cause of the failure.
     */
    case failure(error: StitchError)
}
