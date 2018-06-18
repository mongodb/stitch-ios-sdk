import Foundation

/**
 * An enumeration representing the types of errors that may be thrown by the Stitch SDK.
 */
public enum StitchError: Error {
    /**
     * Indicates that an error came from the Stitch server after a request was completed, with an error message and an
     * error defined in the `StitchServiceErrorCode` enum.
     *
     * It is possible that the error code will be
     * `StitchServiceErrorCode.unknown`, which can mean one of several possibilities: the Stitch server returned a
     * message that this version of the SDK does not yet recognize, the server is not a Stitch server and returned an
     * unexpected message, or the response was corrupted. In these cases, the associated message will be the plain text
     * body of the response, or `nil` if the body is empty or not decodable as plain text.
     */
    case serviceError(withMessage: String, withServiceErrorCode: StitchServiceErrorCode)

    /**
     * Indicates that an error occurred while a request was being carried out. This could be due to (but is not
     * limited to) an unreachable server, a connection timeout, or an inability to decode the result. In the case of
     * transport errors, these errors are thrown by the underlying `Transport` of the Stitch client, and thus contain
     * the error that the transport threw. Errors in decoding the result from the server include the specific error
     * thrown when attempting to decode the response. An error code is included, which indicates whether the error
     * was a transport error or decoding error.
     */
    case requestError(withError: Error, withRequestErrorCode: StitchRequestErrorCode)

    /**
     * Indicates that an error occurred when using the Stitch client, typically before the client performed a request.
     * An error code indicating the reason for the error is included.
     */
    case clientError(withClientErrorCode: StitchClientErrorCode)
}

/**
 * An enumeration of the types of errors that can come back from a completed request to the Stitch server. With the
 * exception of `.unknown`, these are the error codes as they are returned by the Stitch server in an error response.
 */
public enum StitchServiceErrorCode: String, Codable {
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
    userDisabled = "UserDisabled",
    unknown = "Unknown"
}

/**
 * An enumeration indicating the types of errors that may occur when carrying out a Stitch request.
 */
public enum StitchRequestErrorCode {
    case transportError
    case decodingError
    case encodingError
    case unknownError
}

/**
 * An enumeration indicating the types of errors that may occur when using a Stitch client, typically before a
 * request is made.
 */
public enum StitchClientErrorCode {
    case loggedOutDuringRequest
    case missingURL
    case mustAuthenticateFirst
    case userNoLongerValid
    case couldNotLoadPersistedAuthInfo
    case couldNotPersistAuthInfo
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
    let errorCode: StitchServiceErrorCode

    /**
     * Private helper method which decodes the Stitch error from the body of an HTTP `Response` object. If the error
     * cannot be decoded, this is likely not an error from the Stitch server, and it will throw a
     * `StitchError.serviceError` with a `.unknown` error code.
     */
    private static func handleRichError(forResponse response: Response,
                                        withBody body: Data) throws -> StitchErrorCodable {
        // If this is not a JSON error, throw a `StitchError.serviceError` error with a `.unknown` error code and the
        // body of the response as a UTF8 string as the message. If there is no body or it cannot be decoded as UTF8,
        // throw an unknown error with no message.
        guard let contentType = response.headers[Headers.contentType.nonCanonical()],
                  contentType == ContentTypes.applicationJSON.rawValue else {
                guard let content = String.init(data: body, encoding: .utf8) else {
                    throw StitchError.serviceError(
                        withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                        withServiceErrorCode: .unknown
                    )
                }

                throw StitchError.serviceError(withMessage: content, withServiceErrorCode: .unknown)
        }

        // Try decoding the JSON error as a `StitchErrorCodable`. If it can't be decoded, try throwing an unknown error
        // with the JSON as the message, or an empty message if the JSON can't be decoded as a UTF8 string.
        guard let error = try? JSONDecoder().decode(StitchErrorCodable.self,
                                                   from: body) else {
            guard let content = String.init(data: body, encoding: .utf8) else {
                throw StitchError.serviceError(
                    withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                    withServiceErrorCode: .unknown
                )
            }

            throw StitchError.serviceError(withMessage: content, withServiceErrorCode: .unknown)
        }

        // Return the decoded error
        return error
    }

    /**
     * Static utility method that accepts an HTTP `Response` object, and returns the `StitchError` representing the
     * the error in the response. If the error cannot be recognized, this will return a `StitchError.serviceError` with
     * the `.unknown` error code.
     */
    public static func handleError(forResponse response: Response) -> StitchError {
        guard let body = response.body else {
            return StitchError.serviceError(
                withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                withServiceErrorCode: .unknown
            )
        }

        var errorCodable: StitchErrorCodable!
        do {
            errorCodable = try handleRichError(forResponse: response,
                                            withBody: body)
        } catch let err {
            // If handleRichError threw an error, return it as the error if it is a `StitchError`, or a
            // `StitchError.serviceError` with an unknown code otherwise.
            return err as? StitchError ?? StitchError.serviceError(
                withMessage: StitchErrorCodable.genericErrorMessage(withStatusCode: response.statusCode),
                withServiceErrorCode: .unknown
            )
        }

        // Return the StitchError.serviceError for the decoded error
        return StitchError.serviceError(withMessage: errorCodable.error,
                                        withServiceErrorCode: errorCodable.errorCode)

    }

    /**
     * Static utility function which returns a generic error message for a particualr HTTP status code.
     */
    public static func genericErrorMessage(withStatusCode statusCode: Int) -> String {
        return "received unexpected status code \(statusCode)"
    }
}
