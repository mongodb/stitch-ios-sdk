import Foundation
import StitchCoreSDK

/**
 * `StitchResult` holds the result to an asynchronous operation performed against the Stitch server. When the operation
 * was completed successfully, it holds the result of the operation. When the operation fails, it contains a
 * `StitchError` object describing the reason for the failure.
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
