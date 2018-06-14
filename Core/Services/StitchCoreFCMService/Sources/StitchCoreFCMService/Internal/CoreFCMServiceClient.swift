import Foundation
import MongoSwift
import StitchCoreSDK

public class CoreFCMServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withServiceClient serviceClient: CoreStitchServiceClient) {
        self.service = serviceClient
    }
    
    public func sendMessage(to recipient: String,
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendFields.toField.rawValue,
            targetTypeValue: recipient
        )
    }
    
    public func sendMessage(toUserIds userIds: [String],
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendFields.userIdsField.rawValue,
            targetTypeValue: userIds
        )
    }
    
    public func sendMessage(toRegistrationTokens registrationTokens: [String],
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendFields.registrationTokensField.rawValue,
            targetTypeValue: registrationTokens
        )
    }
    
    private func sendMessageInternal<T: BsonValue>(request: FCMSendMessageRequest,
                                     targetTypeKey: String,
                                     targetTypeValue: T) throws -> FCMSendMessageResult {
        var args = try BsonEncoder().encode(request)
        args[targetTypeKey] = targetTypeValue
        return try self.service.callFunctionInternal(
            withName: CoreFCMServiceClient.sendAction,
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    private static let sendAction = "send"
    
    private enum SendFields: String {
        // Target types
        case userIdsField = "userIds"
        case toField = "to"
        case registrationTokensField = "registrationTokens"
    }
}
