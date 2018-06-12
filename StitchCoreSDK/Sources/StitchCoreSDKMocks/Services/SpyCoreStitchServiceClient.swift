import Foundation
import MongoSwift
import MockUtils
@testable import StitchCoreSDK

public final class SpyCoreStitchServiceClient: CoreStitchServiceClientImpl {
    public override init(requestClient: StitchAuthRequestClient,
                routes: StitchServiceRoutes,
                serviceName: String?) {
        super.init(requestClient: requestClient, routes: routes, serviceName: serviceName)
    }
    public var callFunctionInternalSpy = FunctionSpyUnitThreeArgs<String, [BsonValue], TimeInterval?>()
    public override func callFunctionInternal(withName name: String,
                                              withArgs args: [BsonValue],
                                              withRequestTimeout requestTimeout: TimeInterval?) throws {
        callFunctionInternalSpy.run(arg1: name, arg2: args, arg3: requestTimeout)
        return try super.callFunctionInternal(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
    }
    
    public var callFunctionInternalWithDecodingSpy =
        FunctionSpyUnitThreeArgs<String, [BsonValue], TimeInterval?>()
    public override func callFunctionInternal<T>(withName name: String,
                                                 withArgs args: [BsonValue],
                                                 withRequestTimeout requestTimeout: TimeInterval?)
        throws -> T where T : Decodable {
        callFunctionInternalWithDecodingSpy.run(arg1: name, arg2: args, arg3: requestTimeout)
        return try super.callFunctionInternal(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
    }
}
