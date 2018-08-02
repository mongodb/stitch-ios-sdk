import Foundation
import MongoSwift
import StitchCoreSDK

public final class CoreAWSServiceClient {
    private let service: CoreStitchServiceClient
    
    public init(withService service: CoreStitchServiceClient) {
        self.service = service
    }
    
    public func execute(request: AWSRequest, withRequestTimeout requestTimeout: TimeInterval? = nil) throws {
        try service.callFunction(
            withName: Field.executeAction.rawValue,
            withArgs: [getRequestArgs(fromRequest: request)],
            withRequestTimeout: requestTimeout
        )
    }
    
    public func execute<T: Decodable>(
        request: AWSRequest,
        withRequestTimeout requestTimeout: TimeInterval? = nil
        ) throws -> T {
        return try service.callFunction(
            withName: Field.executeAction.rawValue,
            withArgs: [getRequestArgs(fromRequest: request)],
            withRequestTimeout: requestTimeout
        )
    }
    
    private func getRequestArgs(fromRequest request: AWSRequest) -> Document {
        var args: Document = [
            Field.serviceParam.rawValue: request.service,
            Field.actionParam.rawValue: request.action,
            Field.argumentsParam.rawValue: request.arguments
        ]
        
        if let region = request.region {
            args[Field.regionParam.rawValue] = region
        }
        
        return args
    }
    
    private enum Field: String {
        case executeAction = "execute"
        case serviceParam = "aws_service"
        case actionParam = "aws_action"
        case regionParam = "aws_region"
        case argumentsParam = "aws_arguments"
    }
}
