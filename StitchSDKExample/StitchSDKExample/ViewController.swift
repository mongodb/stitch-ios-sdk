import UIKit
import StitchSDK
import MongoSwift

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
        self.stitchClient.callFunction(
            withName: "getBool", withArgs: abcr, withRequestTimeout: 5.0
        ) { (result: StitchResult<Bool>) in
            switch result {
            case .success(let boolResult):
                print("Bool result: \(boolResult)")
            case .failure(let error):
                print("Error retrieving Bool: \(String(describing: error))")
            }
        }
    }

    @IBAction func functionTwoPressed(_ sender: Any) {
        self.stitchClient.callFunction(
            withName: "getObject", withArgs: [], withRequestTimeout: 5.0
        ) { (result: StitchResult<Document>) in
            switch result {
            case .success(let docResult):
                print("Document result: \(docResult)")
            case .failure(let error):
                print("Error retrieving Document: \(String(describing: error))")
            }
        }
    }

    @IBAction func functionThreePressed(_ sender: Any) {
        stitchClient.callFunction(
            withName: "echoArg", withArgs: ["Hello world!"], withRequestTimeout: 5.0
        ) { (result: StitchResult<String>) in
            switch result {
            case .success(let stringResult):
                print("String result: \(stringResult)")
            case .failure(let error):
                print("Error retrieving String: \(String(describing: error))")
            }
        }
    }

    @IBAction func loginButtonPressed(_ sender: Any) {
        print(UIDevice.current.systemName)

        stitchClient.auth.login(withCredential: AnonymousCredential()) { result in //user, error in
            switch result {
            case .success(let user):
                print("Logged in as user \(user.id)")
                DispatchQueue.main.async {
                    self.updateLoginStatusUILabel()
                }
            case .failure(let error):
                print("Failed to log in: \(error)")
            }
        }
    }
}
