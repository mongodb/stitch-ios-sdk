import Foundation

/**
 * The result of an AWS S3 sign policy request. (Deprecated)
 */
@available(*, deprecated, message: "Use AWSServiceClient instead")
public struct AWSS3SignPolicyResult: Decodable {
    /**
     * The description of the policy that has been signed.
     */
    public let policy: String
    
    /**
     * The computed signature of the policy.
     */
    public let signature: String
    
    /**
     * The algorithm used to compute the signature.
     */
    public let algorithm: String
    
    /**
     * The date at which the signature was computed.
     */
    public let date: String
    
    /**
     * The credential that should be used when utilizing this signed policy.
     */
    public let credential: String
}
