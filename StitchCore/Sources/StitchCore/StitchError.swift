import Foundation

/**
 * An enum representing an error returned from a server upon a completed request
 *
 * - important: A `StitchError` is only thrown if a request to a server has been completed. Transport-related errors,
 *              such as being unable to connect to a server, are thrown by the underlying `Transport` that the Stitch
 *              client is configured with, and will not be one of these errors. If no `Transport` is specified,
 *              transport errors will be ones that are normally thrown by `URLSession.dataTask`.
 */
public enum StitchError: Error {
    /**
     * Indicates that the error was specifically from a Stitch server, with an error message and an error code
     * defined in the `StitchErrorCode` enum.
     */
    case serviceError(withMessage: String, withErrorCode: StitchErrorCode)

    /**
     * Indicates that the error type received from the server is not known. This may be due to a corrupted
     * response, an error unrelated to Stitch (perhaps the server being contacted is not actually a Stitch server), or
     * a new type of error that this version of the Stitch iOS SDK does not currently recognize. The error will be
     * accompanied with a message unless the response was empty or could not be decoded as JSON or UTF-8 plaintext.
     */
    case unknownError(withMessage: String?)
}

/**
 * An enumeration indicating the errors that may occur when using a Stitch client. These errors are thrown
 * before the client performs any request against the server.
 */
public enum StitchClientError: Error {
    case loggedOutDuringRequest
    case missingURL
    case mustAuthenticateFirst
    case userNoLongerValid
}

/**
 * An enumeration of the types of errors that can come back from a completed request to the Stitch server. These are
 * the error codes as they are returned by the Stitch server in an error response.
 */
public enum StitchErrorCode: String, Codable, Error {
    case missingAuthReq = "MissingAuthReq",
    /// Invalid session, expired, no associated user, or app domain mismatch
    invalidSession = "InvalidSession",
    userAppDomainMismatch = "UserAppDomainMismatch",
    domainNotAllowed = "DomainNotAllowed",
    readSizeLimitExceeded = "ReadSizeLimitExceeded",
    invalidParameter = "InvalidParameter",
    missingParameter = "MissingParameter",
    twilioError = "TwilioError",
    gcmError = "GCMError",
    httpError = "HTTPError",
    awsError = "AWSError",
    mongoDBError = "MongoDBError",
    argumentsNotAllowed = "ArgumentsNotAllowed",
    functionExecutionError = "FunctionExecutionError",
    noMatchingRuleFound = "NoMatchingRuleFound",
    internalServerError = "InternalServerError",
    authProviderNotFound = "AuthProviderNotFound",
    authProviderAlreadyExists = "AuthProviderAlreadyExists",
    serviceNotFound = "ServiceNotFound",
    serviceTypeNotFound = "ServiceTypeNotFound",
    serviceAlreadyExists = "ServiceAlreadyExists",
    serviceCommandNotFound = "ServiceCommandNotFound",
    valueNotFound = "ValueNotFound",
    valueAlreadyExists = "ValueAlreadyExists",
    valueDuplicateName = "ValueDuplicateName",
    functionNotFound = "FunctionNotFound",
    functionAlreadyExists = "FunctionAlreadyExists",
    functionDuplicateName = "FunctionDuplicateName",
    functionSyntaxError = "FunctionSyntaxError",
    functionInvalid = "FunctionInvalid",
    incomingWebhookNotFOund = "IncomingWebhookNotFound",
    incomingWebhookAlreadyExists = "IncomingWebhookAlreadyExists",
    incomingWebhookDuplicateName = "IncomingWebhookDuplicateName",
    ruleNotFound = "RuleNotFound",
    apiKeyNotFound = "APIKeyNotFound",
    ruleAlreadyExists = "RuleAlreadyExists",
    ruleDuplicateName = "RuleDuplicateName",
    authProviderDuplicateName = "AuthProviderDuplicateName",
    restrictedHost = "RestrictedHost",
    apiKeyAlreadyExists = "APIKeyAlreadyExists",
    incomingWebhookAuthFailed = "IncomingWebhookAuthFailed",
    executionTimeLimitExceeded = "ExecutionTimeLimitExceeded",
    notCallable = "FunctionNotCallable",
    userAlreadyConfirmed = "UserAlreadyConfirmed",
    userNotFound = "UserNotFound",
    userDisabled = "UserDisabled"
}

/**
 * `StitchErrorCodable` represents a Stitch error as it exists in the response to a request to the Stitch server. The
 * class contains a static function that can return the appropriate `StitchError` from an HTTP `Response`.
 */
internal struct StitchErrorCodable: Codable {
    private enum CodingKeys: String, CodingKey {
        case error, errorCode = "error_code"
    }

    /**
     * The error message from the server.
     */
    let error: String

    /**
     * The error code from the server.
     */
    let errorCode: StitchErrorCode

    /**
     * Private helper method which decodes the Stitch error from the body of an HTTP `Response` object. If the error
     * cannot be decoded, this is likely not an error from the Stitch server, and it will throw a
     * `StitchError.unknownError`.
     */
    private static func handleRichError(forResponse response: Response,
                                        withBody body: Data) throws -> StitchErrorCodable {
        // If this is not a JSON error, throw a `StitchError.unknownError` error with the body of the response as a
        // UTF8 string as the message. If there is no body or it cannot be decoded as UTF8, throw an unknown error with
        // no message.
        guard let contentType = response.headers[Headers.contentType.rawValue],
            contentType == ContentTypes.applicationJson.rawValue else {
                guard let content = String.init(data: body, encoding: .utf8) else {
                    throw StitchError.unknownError(withMessage: nil)
                }

                throw StitchError.unknownError(withMessage: content)
        }

        // Try decoding the JSON error as a `StitchErrorCodable`. If it can't be decoded, try throwing an unknown error
        // with the JSON as the message, or an empty message if the JSON can't be decoded as a UTF8 string.
        guard let error = try? JSONDecoder().decode(StitchErrorCodable.self,
                                                   from: body) else {
            guard let content = String.init(data: body, encoding: .utf8) else {
                throw StitchError.unknownError(withMessage: nil)
            }
            throw StitchError.unknownError(withMessage: content)
        }

        // Return the decoded error
        return error
    }

    /**
     * Static utility method that accepts an HTTP `Response` object, and returns the `StitchError` representing the
     * the error in the response. If the error cannot be recognized, this will return a `StitchError.unknownError`, or
     * a `StitchError.emptyResponseError` if the response had no body.
     */
    public static func handleError(inResponse response: Response) -> StitchError {
        guard let body = response.body else {
            return StitchError.unknownError(withMessage: nil)
        }

        var errorCodable: StitchErrorCodable!
        do {
            errorCodable = try handleRichError(forResponse: response,
                                            withBody: body)
        } catch let err {
            // If handleRichError threw an error, return it as the error if it is a `StitchError`, or a
            // `StitchError.unknownError` otherwise.
            return err as? StitchError ?? StitchError.unknownError(withMessage: nil)
        }

        // Return the StitchError.serviceError for the decoded error
        return StitchError.serviceError(withMessage: errorCodable.error,
                                        withErrorCode: errorCodable.errorCode)

    }
}
