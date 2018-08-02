import Foundation
import StitchCore
import StitchCoreSDK
import StitchCoreAWSService

private final class AWSNamedServiceClientFactory: NamedServiceClientFactory {
    typealias ClientType = AWSServiceClient
    
    func client(withServiceClient serviceClient: CoreStitchServiceClient,
                withClientInfo clientInfo: StitchAppClientInfo) -> AWSServiceClient {
        return AWSServiceClientImpl(
            withClient: CoreAWSServiceClient.init(withService: serviceClient),
            withDispatcher: OperationDispatcher(withDispatchQueue: DispatchQueue.global())
        )
    }
}

/**
 * Global factory const which can be used to create an `AWSServiceClient` with a `StitchAppClient`. Pass into
 * `StitchAppClient.serviceClient(fromFactory:withName)` to get an `AWSServiceClient.
 */
public let awsServiceClientFactory =
    AnyNamedServiceClientFactory<AWSServiceClient>(factory: AWSNamedServiceClientFactory())

/**
 * The AWS service client, which can be used to interact with AWS via MongoDB Stitch.
 */
public protocol AWSServiceClient {
    
    /**
     * Executes the AWS request.
     *
     * - parameters:
     *     - request the AWS request to execute.
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will be ignored.
     */
    func execute(request: AWSRequest, _ completionHandler: @escaping (StitchResult<Void>) -> Void)
    
    /**
     * Executes the AWS request. Also accepts a timeout. Use this for functions that may run longer than the
     * client-wide default timeout (15 seconds by default).
     *
     * - parameters:
     *     - request the AWS request to execute.
     *     - withRequestTimeout: The number of seconds the client should wait for a response from the server before
     *                           failing with an error.
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will be ignored.
     */
    func execute(request: AWSRequest, withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<Void>) -> Void)
    
    /**
     * Executes the AWS request, and decodes the result into an instance of the type parameter T.
     *
     * - parameters:
     *     - request the AWS request to execute.
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will decoded into the type T and will be included in the result.
     */
    func execute<T: Decodable>(request: AWSRequest, _ completionHandler: @escaping (StitchResult<T>) -> Void)
    
    /**
     * Executes the AWS request, and decodes the result into an instance of the type parameter T. Also accepts a
     * timeout. Use this for functions that may run longer than the client-wide default timeout (15 seconds by
     * default).
     *
     * - parameters:
     *     - request the AWS request to execute.
     *     - withRequestTimeout: The number of seconds the client should wait for a response from the server before
     *                           failing with an error.
     *     - completionHandler: The completion handler to call when the request is complete or the operation fails.
     *                          This handler is executed on a non-main global `DispatchQueue`. If the operation is
     *                          successful, the result will decoded into the type T and will be included in the result.
     */
    func execute<T: Decodable>(request: AWSRequest, withRequestTimeout requestTimeout: TimeInterval, _ completionHandler: @escaping (StitchResult<T>) -> Void)
    
}
