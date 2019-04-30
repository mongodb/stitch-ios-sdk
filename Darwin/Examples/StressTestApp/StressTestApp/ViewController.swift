import UIKit
import StitchCore
import MongoSwift
import StitchCoreSDK
@testable import StitchRemoteMongoDBService
@testable import StitchCoreRemoteMongoDBService

class ViewController: UIViewController {
    // Stitch Variables:
    private lazy var stitchClient = Stitch.defaultAppClient!
    private var mongoClient: RemoteMongoClient!
    private var mongoCollection: RemoteMongoCollection<Document>!
    private var syncCollection: Sync<Document>!
    
    // UI Elements
    @IBOutlet weak var numSyncedDocsLabel: UILabel!
    
    @IBOutlet weak var numDocsToInsertInput: UITextField!
    @IBOutlet weak var docSizeInput: UITextField!
    
    @IBOutlet weak var insertManyButton: UIButton!
    @IBOutlet weak var clearAllDocsButton: UIButton!
    @IBOutlet weak var syncPassButton: UIButton!
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var networkSentLabel: UILabel!
    @IBOutlet weak var networkReceivedLabel: UILabel!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let cornerRadius: CGFloat = 20;
        insertManyButton.layer.cornerRadius = cornerRadius;
        clearAllDocsButton.layer.cornerRadius = cornerRadius;
        syncPassButton.layer.cornerRadius = cornerRadius;
        
        // Keyboard dismissal
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        
        // Initialize Stitch RemoteMongoDBService and RemoteMongoCollection
        mongoClient = try! stitchClient.serviceClient(fromFactory: remoteMongoClientFactory, withName: "mongodb-atlas")
        mongoCollection = mongoClient.db("stress").collection("tests");
        syncCollection = mongoCollection.sync

        syncCollection?.configure(
            conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
            changeEventDelegate:  { documentId, event in
                self.log("Sync received changeEvent of type: \(event.operationType) and body: \(String(describing: event.fullDocument))")
                if (event.hasUncommittedWrites) {
                    self.log("Sync changeEvent has uncommitted writes")
                }
            }, errorListener: self.on(error:forDocumentId:)) { result in
                switch result {
                case .success:
                    self.log("Successfully Configured sync");
                    self.syncCollection.proxy.dataSynchronizer.isSyncThreadEnabled = false
                    self.syncCollection.proxy.dataSynchronizer.stop()
                case .failure(let error):
                    self.log("Failed to auth with error: \(error)");
                }
            }

        stitchClient.auth.login(withCredential: AnonymousCredential()) { result in
            switch result {
            case .success(let user):
                self.log("Successfully authenticated with user: \(user.id)");
            case .failure(let error):
                fatalError("Failed to auth with error: \(error)")
            }
        }
    }

    @IBAction func insertManyClicked(_ sender: Any) {
        
        guard let userId = stitchClient.auth.currentUser?.id else {
            self.log(" insertManyClicked: Must be logged in")
            return;
        }
        
        guard let syncCollection = syncCollection else {
            self.log(" insertManyClicked: Sync must be initialized")
            return;
        }
        
        labelsInProgress()
        let time = Date.init()
        let networkRecieved = appDelegate.transport.bytesDownloaded
        let networkSent = appDelegate.transport.bytesUploaded
        
        let numDocs = integer(from: numDocsToInsertInput);
        let docSize = integer(from: docSizeInput);
        
        self.syncCollection.proxy.dataSynchronizer.isSyncThreadEnabled = false
        self.syncCollection.proxy.dataSynchronizer.stop()
        
        // Create the documents
        var docs: [Document] = [];
        for i in 1...numDocs {
            do {
                let newDoc: Document = try ["_id": ObjectId(),
                                            "owner_id": userId,
                                            "data": Binary(data: Data(repeating: UInt8(i % 100), count: docSize),
                                                           subtype: Binary.Subtype.userDefined)]
                docs.append(newDoc)
            } catch(let err) {
                self.log("Failed to make array of documents with error: \(err.localizedDescription)")
            }
        }
        
        // Insert the documents in chunks
        let chunkSize = 500;
        let group  = DispatchGroup()
        var docIds : [BSONValue] = [];
        for (i, docChunk) in docs.chunks(chunkSize).enumerated() {
            group.enter()
            mongoCollection?.insertMany(docChunk) { result in
                switch result {
                case .success(let result):
                    self.log("Successfully inserted chunk #\(i)")
                    docIds += result.insertedIds.map({$0.value})
                case .failure(let error):
                    self.log("Failed to insert chunk #\(i) with err: \(error.localizedDescription)")
                }
                group.leave()
            }
        }
        
        // When finished inserting the documents --> sync on the doc id's and collect time and network metrics
        group.notify(queue: .main) {
            self.log("Finished with \(docIds.count) docs")
            syncCollection.sync(ids: docIds) {result in
                switch result {
                case .success(result: _):
                    self.log("Succeffully synced \(docIds.count) docs");
                    let newTime = Date.init().msSinceEpoch - time.msSinceEpoch
                    let newBytesSent = self.appDelegate.transport.bytesUploaded - networkSent
                    let newBytesRec = self.appDelegate.transport.bytesDownloaded - networkRecieved
                    self.updateLabels(withTime: newTime, withNetworkSent: newBytesSent, withNetworkRec: newBytesRec)
                case .failure(let error):
                     self.log("Failed to sync #\(docIds.count) docs with err: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @IBAction func clearAllDocsClicked(_ sender: Any) {
        guard let _ = stitchClient.auth.currentUser?.id else {
            self.log(" clearAllDocsClicked: Must be logged in")
            return;
        }
        
        guard let syncCollection = syncCollection else {
            self.log(" clearAllDocsClicked: Must have valid syncCollection")
            return;
        }
        syncCollection.syncedIds() { result in
            switch result {
            case .success(let syncedIds):
                if (syncedIds.count > 0) {
                    syncCollection.desync(ids: syncedIds.map({return $0.value})) {result in
                        switch result {
                        case .success(result: _):
                            self.log("Succeffully de-synced \(syncedIds.count) docs");
                        case .failure(let error):
                            self.log("Failed to de-sync #\(syncedIds.count) docs with err: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                self.log("Failed to get synced ids with err: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func syncPassClicked(_ sender: Any) {
        performSyncPass()
    }
    
    func performSyncPass() {
        guard let syncCollection = syncCollection else {
            self.log(" clearAllDocsClicked: Must have valid syncCollection")
            return;
        }
        
        labelsInProgress()
        let time = Date.init()
        let networkRecieved = appDelegate.transport.bytesDownloaded
        let networkSent = appDelegate.transport.bytesUploaded

        self.log("Performing Sync Pass")
        do {
            let result = try syncCollection.proxy.dataSynchronizer.doSyncPass()
            self.log("Finishing Sync Pass: \(result)")
        } catch {
            self.log("Failed to SyncPass() with err: \(error)")
        }
        
        let newTime = Date.init().msSinceEpoch - time.msSinceEpoch
        let newBytesSent = appDelegate.transport.bytesUploaded - networkSent
        let newBytesRec = appDelegate.transport.bytesDownloaded - networkRecieved
        self.updateLabels(withTime: newTime, withNetworkSent: newBytesSent, withNetworkRec: newBytesRec)
        
        syncCollection.proxy.dataSynchronizer.stop()
    }
    
    func integer(from textField: UITextField) -> Int {
        guard let text = textField.text, let number = Int(text) else {
            return 1
        }
        return number
    }
    
    func on(error: DataSynchronizerError, forDocumentId documentId: BSONValue?) {
        log("Sync errorHandler failed with: \(error)")
    }
    
    func log(_ logMsg: String) {
        print("(StressTest): \(logMsg)")
    }
    
    func updateLabels(withTime time: Int64 = 0, withNetworkSent networkSent: Int64 = 0, withNetworkRec networkRec: Int64 = 0) {
        syncCollection?.syncedIds() { result in
            switch result {
            case .success(let syncedIds):
                DispatchQueue.main.async() {
                    self.timeLabel.text             = "\(String(describing: time))"
                    self.networkSentLabel.text      = "\(String(describing: networkSent))"
                    self.networkReceivedLabel.text  = "\(String(describing: networkRec))"
                    self.numSyncedDocsLabel.text    = "\(String(describing: syncedIds.count))"
                }
            case .failure(let error):
                self.log("Failed to get synced ids with err: \(error.localizedDescription)")
            }
        }
    }
    
    func labelsInProgress() {
        DispatchQueue.main.async {
            self.timeLabel.text = "In Progress"
            self.networkSentLabel.text = "In Progress"
            self.networkReceivedLabel.text = "In Progress"
        }
    }
}

extension Array {
    func chunks(_ chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

