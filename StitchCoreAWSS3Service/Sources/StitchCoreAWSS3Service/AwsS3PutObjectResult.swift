import Foundation

/**
 * The result of an AWS S3 put object request.
 */
public struct AwsS3PutObjectResult: Decodable {
    /**
     * The location of the object.
     */
    public let location: String
}
