import UIKit
import StitchCore_iOS
import MongoSwift
import StitchCore

class ViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateLoginStatusUILabel()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func updateLoginStatusUILabel() {
        switch stitchClient.auth.isLoggedIn {
        case true:
            statusLabel.text = stitchClient.auth.currentUser?.id
        case false:
            statusLabel.text = "Not logged in."
        }
    }

    private lazy var stitchClient: StitchAppClient! = try? Stitch.getDefaultAppClient()

    @IBAction func functionOnePressed(_ sender: Any) {
        let abcr = ["1", 1] as [BsonValue]
        self.stitchClient.callFunction(withName: "getBool", withArgs: abcr, withRequestTimeout: 5.0) { (value: Bool?, error: Error?) in
            print("Bool: \(String(describing: value as? Bool)), Error: \(String(describing: error))")
        }
    }

    @IBAction func functionTwoPressed(_ sender: Any) {
        self.stitchClient.callFunction(withName: "getObject", withArgs: [], withRequestTimeout: 5.0) { (value: Document?, error: Error?) in
            print("Object: \(String(describing: value)), Error: \(String(describing: error))")
        }
    }

    @IBAction func functionThreePressed(_ sender: Any) {
        stitchClient.callFunction(withName: "echoArg", withArgs: ["Hello world!"], withRequestTimeout: 5.0) { (value, error) in
            print("Message: \(value ?? "None")\nError: \(String(describing: error))")
        }
    }

    @IBAction func loginButtonPressed(_ sender: Any) {
        print(UIDevice.current.systemName)

        stitchClient.auth.login(withCredential: AnonymousCredential()) { user, error in
            if let error = error {
                print("Failed to log in: \(error)")
            } else if let user = user {

                print("Logged in as user \(user.id)")
                DispatchQueue.main.async {
                    self.updateLoginStatusUILabel()
                }
            }
        }
    }
}
