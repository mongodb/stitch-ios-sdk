import Foundation

/**
 * An enum indicating the fields expected in a `CoreStitchAuth`'s `deviceInfo` BSON document.
 */
public enum DeviceField: String {
    /**
     * The current user's device id.
     */
    case deviceID = "deviceId"

    /**
     * The name of the local application.
     */
    case appID = "appId"

    /**
     * The current version of the local application.
     */
    case appVersion

    /**
     * The identifer for the current device's platform. (eg. "iOS")/
     */
    case platform

    /**
     * The version of the current device's platform.
     */
    case platformVersion

    /**
     * The version of the Stitch SDK that the device is currently using.
     */
    case sdkVersion
}
