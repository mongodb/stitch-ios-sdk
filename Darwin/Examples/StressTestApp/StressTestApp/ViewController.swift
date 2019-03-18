//
//  ViewController.swift
//  StressTestApp
//
//  Created by Tyler Kaye on 3/14/19.
//  Copyright © 2019 Tyler Kaye. All rights reserved.
//

import UIKit
import StitchCore
import MongoSwift
import StitchRemoteMongoDBService
import StitchLocalMongoDBService
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

class ViewController: UIViewController {
    // Stitch Variables:
    private lazy var stitchClient = Stitch.defaultAppClient!
    private var mongoClient: RemoteMongoClient?
    private var mongoCollection: RemoteMongoCollection<Document>?
    private var syncCollection: Sync<Document>?
    
    // UI Elements
    @IBOutlet weak var numSyncedDocsLabel: UILabel!
    
    @IBOutlet weak var numDocsToInsertInput: UITextField!
    @IBOutlet weak var docSizeInput: UITextField!
    
    @IBOutlet weak var insertManyButton: UIButton!
    @IBOutlet weak var clearAllDocsButton: UIButton!
    @IBOutlet weak var syncPassButton: UIButton!
    
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var cpuLabel: UILabel!
    
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
        do {
            mongoClient = try stitchClient.serviceClient(fromFactory: remoteMongoClientFactory, withName: "mongodb-atlas")
            mongoCollection = mongoClient?.db("stress").collection("tests");
            syncCollection = mongoCollection?.sync
            syncCollection?.configure(
                conflictHandler: DefaultConflictHandler<Document>.remoteWins(),
                changeEventDelegate: { documentId, event in
                    self.log(" Sync received changeEvent of type: \(event.operationType) and body: \(event.fullDocument)")
                    if (event.hasUncommittedWrites) {
                        self.log(" Sync changeEvent has uncommitted writes")
                    }
            }, errorListener: self.on)
            
            self.log("successfuly setup mongoClient and mongoCollection");
            
            stitchClient.auth.login(withCredential: AnonymousCredential()) { result in
                switch result {
                case .success(let user):
                    self.log("Successfully authenticated with user: \(user.id)");
                case .failure(let error):
                    self.log("Failed to auth with error: \(error)");
                }
            }
        } catch (let err) {
            self.log("Failed initialize mongoClient with error: \(err)");
        }

    }

    @IBAction func insertManyClicked(_ sender: Any) {
        
        guard let userId = stitchClient.auth.currentUser?.id else {
            self.log(" insertManyClicked: Must be logged in")
            return;
        }
        
        timeLabel.text = "In Progress"
        
        let numDocs = integer(from: numDocsToInsertInput);
        let docSize = integer(from: docSizeInput);
        
        var docs: [Document] = [];
        for i in 1...numDocs {
            do {
                let newDoc: Document = try ["_id": ObjectId(),
                                            "owner_id": userId,
                                            "data": Binary(data: Data(repeating: UInt8(i % 100), count: docSize),
                                                           subtype: Binary.Subtype.userDefined)]
                docs.append(newDoc)
            } catch(let err) {
                self.log("Failed to make array of couments with err: \(err.localizedDescription)")
            }
        }
        
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
        
        group.notify(queue: .main) {
            self.log("Finished with \(docIds.count) docs")
            do {
                try self.syncCollection?.sync(ids: docIds)
            } catch (let err) {
                self.log(" sync() failed with err \(err.localizedDescription)")
            }
        }
        
       
        
//        DispatchQueue.main.async() {
//            self.timeLabel.text          = "T: \(String(describing: numDocs))"
//            self.networkLabel.text       = "N: \(String(describing: numDocs))"
//            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
//            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
//        }
    }
    
    @IBAction func clearAllDocsClicked(_ sender: Any) {
        guard let _ = stitchClient.auth.currentUser?.id else {
            self.log(" clearAllDocsClicked: Must be logged in")
            return;
        }
        
        guard let syncCollection = syncCollection else {
            self.log(" clearAllDocsClicked: Must be logged in")
            return;
        }
        let syncedIds = syncCollection.syncedIds;
        if (syncedIds.count > 0) {
            do {
                try syncCollection.desync(ids: syncedIds.map({return $0.value}))
                    // .getServiceClient(RemoteMongoClient.factory, "mongodb-atlas")
                //                    as RemoteMongoClientImpl).dataSynchronizer.doSyncPass()
            } catch (let err) {
                self.log(" desync() failed with err \(err.localizedDescription)")
            }
        }

        let numDocs = integer(from: numDocsToInsertInput)
        DispatchQueue.main.async() {
            self.timeLabel.text          = "T: \(String(describing: numDocs))"
            self.networkLabel.text       = "N: \(String(describing: numDocs))"
            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
        }
    }
    
    @IBAction func syncPassClicked(_ sender: Any) {
        let numDocs = integer(from: numDocsToInsertInput)
        DispatchQueue.main.async() {
            self.timeLabel.text          = "T: \(String(describing: numDocs))"
            self.networkLabel.text       = "N: \(String(describing: numDocs))"
            self.cpuLabel.text           = "C: \(String(describing: numDocs))"
            self.numSyncedDocsLabel.text = "S: \(String(describing: numDocs))"
        }
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
}

extension Array {
    func chunks(_ chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}

