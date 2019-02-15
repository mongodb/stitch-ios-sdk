import MongoSwift
import Foundation
import StitchCoreSDK

/**
 * A special implementation of CoreStitchAuth that communicates with the MongoDB Stitch Admin API.
 */
public final class StitchAdminAuth: CoreStitchAuth<StitchAdminUser> {
    public final override var userFactory: AnyStitchUserFactory<StitchAdminUser> {
        return AnyStitchUserFactory.init(stitchUserFactory: StitchAdminUserFactory.init())
    }

    public final override var deviceInfo: Document {
        var info = Document.init()

        if self.hasDeviceID, let deviceID = self.deviceID {
            info[DeviceField.deviceID.rawValue] = deviceID
        }

        info[DeviceField.appID.rawValue] = "MongoDB Stitch Swift Admin Client"

        return info
    }

    public final override func dispatchAuthEvent(_ authEvent: AuthRebindEvent) {

    }
}
