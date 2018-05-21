import XCTest
import StitchCoreAdminClient
import StitchCore_iOS
import StitchCore
import StitchCoreTestUtils_iOS
import StitchCoreServicesTwilio_iOS
import StitchCoreServicesTwilio

class Stitch_iOSServiceTwilioTests: BaseStitchIntTestCocoaTouch {
    private let twilioSidProp = "test.stitch.twilioSid"
    private let twilioAuthTokenProp = "test.stitch.twilioAuthToken"
    
    private func fetchPList() -> [String: Any]? {
        let testBundle = Bundle(for: Stitch_iOSServiceTwilioTests.self)
        guard let url = testBundle.url(forResource: "Info", withExtension: "plist"),
            let myDict = NSDictionary(contentsOf: url) as? [String:Any] else {
                return nil
        }
        
        return myDict
    }
    
    private lazy var twilioSID: String? = fetchPList()?[twilioSidProp] as? String
    
    private lazy var twilioAuthToken: String? = fetchPList()?[twilioAuthTokenProp] as? String
    
    override func setUp() {
        super.setUp()
        
        XCTAssertTrue(twilioSID != nil, "no Twilio Sid in properties; skipping test")
        XCTAssertTrue(twilioAuthToken != nil, "no Twilio Auth Token in properties; skipping test")
    }
    
    func testSendMessage() throws {
        let app = try self.createApp()
        let _ = try self.addProvider(toApp: app.1, withConfig: ProviderConfigs.anon())
        let svc = try self.addService(
            toApp: app.1,
            withType: "twilio",
            withName: "twilio1",
            withConfig: ServiceConfigs.twilio(name: "twilio1", accountSid: twilioSID!, authToken: twilioAuthToken!)
        )
        let _ = try self.addRule(toService: svc.1,
                                 withConfig: RuleCreator.init(name: "rule",
                                                              actions: RuleActionsCreator.twilio(send: true)))
        
        let client = try self.appClient(forApp: app.0)
        
        let exp0 = expectation(description: "should login")
        client.auth.login(withCredential: AnonymousCredential()) { _,_  in
            exp0.fulfill()
        }
        wait(for: [exp0], timeout: 5.0)
        
        let twilio = client.serviceClient(forService: TwilioService.sharedFactory, withName: "twilio1")
        
        // Sending a random message to an invalid number should fail
        let to = "+15005550010"
        let from = "+15005550001"
        let body = "I've got it!"
        let mediaUrl = "https://jpegs.com/myjpeg.gif.png"
        
        let exp1 = expectation(description: "should not send message")
        twilio.sendMessage(to: to, from: from, body: body, mediaURL: nil) { error in
            switch error as? StitchError {
            case .serviceError(let withMessage, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.twilioError, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 5.0)
        
        let exp2 = expectation(description: "should not send message")
        twilio.sendMessage(to: to, from: from, body: body, mediaURL: mediaUrl) { error in
            switch error as? StitchError {
            case .serviceError(let withMessage, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.twilioError, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 5.0)
        
        // Sending with all good params for Twilio should work
        let fromGood = "+15005550006"
        
        let exp3 = expectation(description: "should send message")
        let exp4 = expectation(description: "should send message")
        twilio.sendMessage(to: to, from: fromGood, body: body, mediaURL: nil) { _ in
            exp3.fulfill()
        }
        twilio.sendMessage(to: to, from: fromGood, body: mediaUrl, mediaURL: nil) { _ in
            exp4.fulfill()
        }
        wait(for: [exp3, exp4], timeout: 5.0)
        
        let exp5 = expectation(description: "should have invalid params")
        // Excluding any required parameters should fail
        twilio.sendMessage(to: to, from: "", body: body, mediaURL: mediaUrl) { error in
            switch error as? StitchError {
            case .serviceError(let withMessage, let withServiceErrorCode)?:
                XCTAssertEqual(StitchServiceErrorCode.invalidParameter, withServiceErrorCode)
            default:
                XCTFail()
            }
            exp5.fulfill()
        }
        wait(for: [exp5], timeout: 5.0)
    }
}
