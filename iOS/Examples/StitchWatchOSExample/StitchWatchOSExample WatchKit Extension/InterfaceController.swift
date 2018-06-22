import WatchKit
import Foundation
import StitchCore
import MongoSwift
import StitchLocalMongoDBService

class InterfaceController: WKInterfaceController {

    @IBOutlet var docLabel: WKInterfaceLabel!
    @IBOutlet var findButton: WKInterfaceButton!
    @IBOutlet var insertButton: WKInterfaceButton!
    
    var collection: MongoCollection<Document>!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        do {
            let client =
                try Stitch.initializeDefaultAppClient("test-app")
            // try to get the default mongo client
            let mongoClient = try client.serviceClient(fromFactory: mongoClientFactory)
            self.collection =
                try mongoClient.db("watchosdb").collection("watchos")
        } catch let err {
            fatalError("Error initializing Stitch: \(err)")
        }
        // Configure interface objects here.
    }
    
    @IBAction func findTouch() {
        guard let cursor = try? self.collection.find(["msg": "watchos is fun"]),
            let doc = cursor.next() else { return }
        
        self.docLabel.setText("found doc: \(doc)")
        let _ = try? self.collection.deleteOne(doc)
    }
    
    @IBAction func insertTouch() {
        let inserted = try? self.collection.insertOne(["msg": "watchos is fun"])
        self.docLabel.setText("_id: \(inserted!!.insertedId)")
    }
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
