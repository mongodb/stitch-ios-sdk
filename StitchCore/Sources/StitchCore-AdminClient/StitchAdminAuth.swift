import ExtendedJSON
import Foundation
import StitchCore

/**
 * A special implementation of CoreStitchAuth that communicates with the MongoDB Stitch Admin API.
 */
public final class StitchAdminAuth: CoreStitchAuth<StitchAdminUser> {
    public final override var userFactory: AnyStitchUserFactory<StitchAdminUser> {
        return AnyStitchUserFactory.init(stitchUserFactory: StitchAdminUserFactory.init())
    }

    public final override var deviceInfo: Document {
        var info = Document.init()

        if self.hasDeviceId, let deviceId = self.deviceId {
            info[DeviceField.deviceId.rawValue] = deviceId
        }

        info[DeviceField.appId.rawValue] = "MongoDB Stitch Swift Admin Client"

        return info
    }

    public final override func onAuthEvent() {
        // do nothing
    }
}
