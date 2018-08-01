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
    public var callFunctionSpy = FunctionSpyUnitThreeArgs<String, [BsonValue], TimeInterval?>()
    public override func callFunction(withName name: String,
                                      withArgs args: [BsonValue],
                                      withRequestTimeout requestTimeout: TimeInterval?) throws {
        callFunctionSpy.run(arg1: name, arg2: args, arg3: requestTimeout)
        return try super.callFunction(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
    }
    
    public var callFunctionWithDecodingSpy =
        FunctionSpyUnitThreeArgs<String, [BsonValue], TimeInterval?>()
    public override func callFunction<T>(withName name: String,
                                         withArgs args: [BsonValue],
                                         withRequestTimeout requestTimeout: TimeInterval?)
        throws -> T where T : Decodable {
        callFunctionWithDecodingSpy.run(arg1: name, arg2: args, arg3: requestTimeout)
        return try super.callFunction(withName: name, withArgs: args, withRequestTimeout: requestTimeout)
    }
}
