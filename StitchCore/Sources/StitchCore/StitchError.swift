import Foundation

public enum StitchError: Error {
    case serviceError(withMessage: String, withErrorCode: StitchErrorCode)
    case requestError(withMessage: String)
}

public struct StitchServiceError: Error {
    let message: String
    let errorCode: StitchErrorCode

    fileprivate init(withMessage message: String,
                     withErrorCode errorCode: StitchErrorCode = .unknown) {
        self.message = message
        self.errorCode = errorCode
    }
}

public enum StitchClientErrors: Error {
    case mustAuthenticateFirst
}

/// ErrorCode represents the set of errors that can come back from a Stitch request.
public enum StitchErrorCode: String, Codable, Error {
    case missingAuthReq = "MissingAuthReq",
    // Invalid session, expired, no associated user, or app domain mismatch
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

public struct StitchErrorCodable: Codable {
    private enum CodingKeys: String, CodingKey {
        case error, errorCode = "error_code"
    }


    let error: String?
    let errorCode: StitchErrorCode?

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

    internal static func handleRequestError(response: Response) -> Error {
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
        
        if (response.statusCode >= 400 && response.statusCode < 600) {
            return StitchError.serviceError(withMessage: error.error!,
                                            withErrorCode: error.errorCode ?? .unknown)
        }

        return StitchError.requestError(withMessage: error.error!)
    }
}
