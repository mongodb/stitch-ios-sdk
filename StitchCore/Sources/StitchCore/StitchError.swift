import Foundation

/**
 * An enum representing an error related to Stitch.
 */
public enum StitchError: Error {
    /**
     * Indicates that the error is related specifically to Stitch, and has an error code defined in the
     * `StitchErrorCode` enum.
     */
    case serviceError(withMessage: String, withErrorCode: StitchErrorCode)

    /**
     * Indicates that the error was with the request made to the Stitch server. This could (but is not
     * limited to) be due to the lack of connectivity or a request timeout.
     */
    case requestError(withMessage: String)
}

/**
 * An enumeration indicating the errors that may occur when using a Stitch client. These errors would be thrown
 * before the client performs any request against the server.
 */
public enum StitchClientError: Error {
    case mustAuthenticateFirst
}

/**
 * An enumeration of the types of errors that can come back from a completed Stitch request.
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
    userDisabled = "UserDisabled",
    unknown = "Unknown",
    invalidURL = "Invalid URL"
}

/**
 * `StitchErrorCodable` represents a Stitch error as it is returned by the Stitch server. The class contains a
 * static function that can return the appropriate `StitchError` or `StitchErrorCode` from an HTTP `Response`.
 */
internal struct StitchErrorCodable: Codable {
    private enum CodingKeys: String, CodingKey {
        case error, errorCode = "error_code"
    }

    /**
     * The error message from the Stitch server.
     */
    let error: String?

    /**
     * The error code from the Stitch server.
     */
    let errorCode: StitchErrorCode?

    /**
     * Private helper method which decodes the Stitch error from the body of an HTTP `Response` object.
     */
    private static func handleRichError(forResponse response: Response,
                                        withBody body: Data) throws -> StitchErrorCodable {
        guard let contentType = response.headers[Headers.contentType.rawValue],
            contentType == ContentTypes.applicationJson.rawValue else {
                guard let content = String.init(data: body, encoding: .utf8) else {
                    throw StitchErrorCode.unknown
                }

                return StitchErrorCodable.init(error: content, errorCode: nil)
        }

        guard let error = try? JSONDecoder().decode(StitchErrorCodable.self,
                                                   from: body) else {
            throw StitchErrorCode.unknown
        }

        return error
    }

    /**
     * Static utility method that accepts an HTTP `Response` object, and returns the `StitchError` contained within
     * the response body. If there is no Stitch error in the body of the response, this will return
     * `StitchErrorCode.unknown`.
     */
    public static func handleRequestError(response: Response) -> Error {
        guard let body = response.body else {
            return StitchErrorCode.unknown
        }

        var error: StitchErrorCodable!
        do {
            error = try handleRichError(forResponse: response,
                                            withBody: body)
        } catch let err {
            return err
        }

        if response.statusCode >= 400 && response.statusCode < 600 {
            return StitchError.serviceError(withMessage: error.error!,
                                            withErrorCode: error.errorCode ?? .unknown)
        }

        return StitchError.requestError(withMessage: error.error!)
    }
}
