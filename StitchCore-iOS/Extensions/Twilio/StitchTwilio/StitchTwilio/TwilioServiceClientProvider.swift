import StitchCore_iOS
import StitchCore
import ExtendedJSON

/// Client for the Twilio platform
public final class TwilioClient {
    private let stitchService: StitchService

    fileprivate init(stitchService: StitchService) {
        self.stitchService = stitchService
    }

    /**
     Send an SMS through to Twilio platform.
     - parameter from: phone number to send from
     - parameter to: phone number to send to
     - parameter body: text body of SMS
    */
    // swiftlint:disable:next identifier_name
    public func send(from: String,
                     to: String,
                     body: String,
                     _ completionHandler: @escaping (Undefined?, Error?) -> Void) throws {
        stitchService.callFunction(withName: "send",
                                   withArgs: [["from": from,
                                               "to": to,
                                               "body": body] as Document],
                                   { completionHandler($0 as? Undefined, $1) })
    }
    // swiftlint:enable:next identifier_name
}

private final class TwilioServiceClientProvider: NamedServiceClientProvider {
    typealias ClientType = TwilioClient

    func client(forService service: StitchService,
                withClient client: StitchAppClientInfo) -> TwilioClient {
        return TwilioClient.init(stitchService: service)
    }
}

/// Service for the Twilio Platform
public let TwilioService = AnyNamedServiceClientProvider<TwilioClient>.init(
    provider: TwilioServiceClientProvider()
)
