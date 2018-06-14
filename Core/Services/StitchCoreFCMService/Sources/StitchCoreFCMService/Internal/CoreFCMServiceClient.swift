import Foundation
import MongoSwift
import StitchCoreSDK

public class CoreFCMServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withServiceClient serviceClient: CoreStitchServiceClient) {
        self.service = serviceClient
    }
    
    public func sendMessage(to target: String,
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendField.to,
            targetTypeValue: target
        )
    }
    
    public func sendMessage(toUserIDs userIDs: [String],
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendField.userIDs,
            targetTypeValue: userIDs
        )
    }
    
    public func sendMessage(toRegistrationTokens registrationTokens: [String],
                            withRequest request: FCMSendMessageRequest) throws -> FCMSendMessageResult {
        return try sendMessageInternal(
            request: request,
            targetTypeKey: SendField.registrationTokens,
            targetTypeValue: registrationTokens
        )
    }
    
    private func sendMessageInternal<T: BsonValue>(request: FCMSendMessageRequest,
                                     targetTypeKey: SendField,
                                     targetTypeValue: T) throws -> FCMSendMessageResult {
        var args = try BsonEncoder().encode(request)
        args[targetTypeKey.rawValue] = targetTypeValue
        return try self.service.callFunctionInternal(
            withName: CoreFCMServiceClient.sendAction,
            withArgs: [args],
            withRequestTimeout: nil
        )
    }
    
    private static let sendAction = "send"
    
    private enum SendField: String {
        // Target types
        case userIDs = "userIds"
        case to
        case registrationTokens
    }
}
