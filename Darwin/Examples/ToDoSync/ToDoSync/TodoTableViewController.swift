import UIKit
import StitchCoreRemoteMongoDBService
import StitchRemoteMongoDBService
import StitchCore
import MongoSwift

private let todoListsDatabase = "todo"
private let todoItemsCollection = "items"
private let todoListsCollection = "lists"

private let tag = "todoTableViewController"

class TodoTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var items: RemoteMongoCollection<TodoItem>!
    private var lists: RemoteMongoCollection<Document>!
    private var userId: String?
    private var todoItems = NSMutableOrderedSet()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                        target: self,
                                        action: #selector(addTodoItem(_:)))

        self.toolBar.items?.append(addButton)
        self.toolBar.sizeToFit()

        let mongoClient = try! stitch.serviceClient(fromFactory: remoteMongoClientFactory,
                                                    withName: "mongodb-atlas")

        // Set up collections
        items = mongoClient
            .db(todoListsDatabase)
            .collection(todoItemsCollection, withCollectionType: TodoItem.self)
        lists = mongoClient
            .db(todoListsDatabase)
            .collection(todoListsCollection)

        // Configure sync to be remote wins on both collections meaning and conflict that occurs should
        // prefer the remote version as the resolution.
        items.sync.configure(
            conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict,
            changeEventDelegate: { documentId, event in
                if event.operationType == .delete {
                    event.id
//                    todoAdapter.removeItemById(event.getDocumentKey().getObjectId("_id").getValue())
                    return
                }
                self.todoItems.add(event.fullDocument!)
                DispatchQueue.main.sync {
                    self.tableView.reloadData()
                }
            },
            errorListener: { (error, _) in
                print(error.localizedDescription)
        })

        lists.sync.configure(
            conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict,
            changeEventDelegate: { documentId, event in
                if !event.hasUncommittedWrites {
                    try! self.items.sync.sync(
                        ids: event.fullDocument!["todos"]! as! [BSONValue])
                }
            },
            errorListener: { (error, _) in
                print(error.localizedDescription)
        })
        self.items.sync.find { result in
            switch result {
            case .success(let todos):
                _ = todos.reduce(into: self.todoItems, { (result, item) in
                    result.add(item)
                })
                DispatchQueue.main.sync {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }

        doLogin()
    }

    @objc func addTodoItem(_ sender: Any) {
        let alertController = UIAlertController.init(title: "Add Item", message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "ToDo item"
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            if let task = alertController.textFields?.first?.text {
                let todoItem = TodoItem.init(id: ObjectId(),
                                             ownerId: self.userId!,
                                             task: task,
                                             checked: false,
                                             doneDate: nil)
                self.lists.sync.updateOne(filter: ["_id": self.userId!],
                                          update: ["$push": ["todos": todoItem.id] as Document],
                                          options: nil)
                { result in
                    switch result {
                    case .success(_):
                        self.todoItems.add(todoItem)
                        DispatchQueue.main.sync {
                            self.tableView.reloadData()
                        }
                    case .failure(let e):
                        print(e)
                    }
                }
            }
        }))
        self.present(alertController, animated: true)
    }

    private func doLogin() {
        stitch.auth.login(withCredential:
        ServerAPIKeyCredential(withKey: "CWQMnJNbgekCq62zWMZAabeQtpRWpHDCKLtef7WLqoyHGvNC5Unn65AXloil1HOx")) {
            switch $0 {
            case .success(let user):
                self.userId = user.id
                print("logged in")

                if self.lists.sync.syncedIds.isEmpty {
                    self.lists.sync.insertOne(document: ["_id": self.userId]) { _ in }
                }
            case .failure(let e):
                print("error logging in \(e)")
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TodoTableViewCell", for: indexPath) as! TodoTableViewCell
        cell.taskLabel.text = (todoItems[indexPath.item] as! TodoItem).task
        return cell
    }
}

