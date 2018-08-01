import Foundation

/**
 * The result of an AWS S3 put object request. (Deprecated)
 */
@available(*, deprecated, message: "Use AWSServiceClient instead")
public struct AWSS3PutObjectResult: Decodable {
    /**
     * The location of the object.
     */
    public let location: String
}
