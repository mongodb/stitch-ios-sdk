import Foundation
import UserNotifications
import ExtendedJson

/**
 * StitchGCMPushClient is the PushClient for GCM. It handles the logic of registering and
 * deregistering with both GCM and Stitch.
 *
 * It does not actively handle updates to the Instance ID when it is refreshed.
 */
public class StitchGCMPushClient: PushClient {
    enum Props: String {
        case GCMServiceName = "gcm"
        case GCMSenderID = "push.gcm.senderId"
    }

    internal let userDefaults: UserDefaults = UserDefaults(suiteName: Consts.UserDefaultsName)!
    private let stitchClient: StitchClient

    private let _info: StitchGCMPushProviderInfo

    /**
        - Parameters:
            - stitchClient: Current `StitchClient` you want to be associated with this push client
            - info: Provider info for your applications gcm
    */
    public init(stitchClient: StitchClient, info: StitchGCMPushProviderInfo) {
        self.stitchClient = stitchClient
        self._info = info
    }

    /**
        - parameter registrationToken: The registration token from GCM.
        - returns: The request payload for registering for push for GCM.
     */
    private func getRegisterPushDeviceRequest(registrationToken: String) throws -> BsonDocument {
        var request = getBaseRegisterPushRequest(serviceName: Props.GCMServiceName.rawValue)
        guard var data = request[DeviceFields.data.rawValue] as? [String: ExtendedJsonRepresentable] else {
            throw StitchError.responseParsingFailed(reason: "device fields not stored properly")
        }
        data[DeviceFields.registrationToken.rawValue] = registrationToken
        request[DeviceFields.data.rawValue] = try BsonDocument.decodeXJson(value: data)
        return request
    }

    /**
     Registers the client with the provider and Stitch
     
     - returns: A task that can be resolved upon registering
     */
    @discardableResult
    public func registerToken(token: String) -> StitchTask<Void> {
        userDefaults.setValue(token, forKey: DeviceFields.registrationToken.rawValue)
        let pipeline: Pipeline = Pipeline(action: Actions.registerPush.rawValue,
                                          args: try? getRegisterPushDeviceRequest(registrationToken: token))

        return stitchClient.executePipeline(pipeline: pipeline).response { task in
            if task.error != nil {
                print(task.error ?? "")
            } else {
                self.addInfoToConfigs(info: self._info)
            }
        }.then { _ in return }
    }

    /**
        Deregisters the client from the provider and Stitch.
     
     - returns: A task that can be resolved upon deregistering
     */
    public func deregister() -> StitchTask<Void> {
        let deviceToken = userDefaults.string(forKey: DeviceFields.registrationToken.rawValue)
        let pipeline: Pipeline = Pipeline(action: Actions.registerPush.rawValue,
                                          args: try? getRegisterPushDeviceRequest(registrationToken: deviceToken!))

        return stitchClient
            .executePipeline(pipeline: pipeline)
            .response { task in
            if task.error != nil {
                print(task.error ?? "")
            } else {
                self.removeInfoFromConfigs(info: self._info)
            }
        }.then { _ in return }
    }
}
