import UIKit
@testable import StitchCoreRemoteMongoDBService
@testable import StitchRemoteMongoDBService
@testable import StitchCore
@testable import StitchCoreSDK
import MongoSwift
import Toast_Swift

private let todoListsDatabase = "todo"
private let todoItemsCollection = "items"
private let todoListsCollection = "lists"

private let tag = "todoTableViewController"

private var toastStyle: ToastStyle {
    var toastStyle = ToastStyle()
    toastStyle.messageFont = .systemFont(ofSize: 10.0)
    return toastStyle
}

private class ItemsStreamDelegate: SSEStreamDelegate {
    private weak var rootView: UIView?
    private weak var streamsLabel: UILabel?

    init(rootView: UIView?, streamsLabel: UILabel?) {
        self.rootView = rootView
        self.streamsLabel = streamsLabel
    }

    override func on(stateChangedFor state: SSEStreamState) {
        DispatchQueue.main.sync {
            streamsLabel?.text = "items stream: \(state)"
        }
    }

    override func on(newEvent event: RawSSE) {
        guard let decoded: ChangeEvent<Document> = try! event.decodeStitchSSE() else {
            return
        }

        DispatchQueue.main.sync {
            let toast = try! rootView?.toastViewForMessage("\(decoded.operationType): \(decoded.documentKey)", title: "items", image: nil, style: toastStyle)

            rootView?.showToast(toast!)
        }
    }
}

private class ListsStreamDelegate: SSEStreamDelegate {
    private weak var rootView: UIView?
    private weak var streamsLabel: UILabel?

    init(rootView: UIView?, streamsLabel: UILabel?) {
        self.rootView = rootView
        self.streamsLabel = streamsLabel
    }

    override func on(stateChangedFor state: SSEStreamState) {
        DispatchQueue.main.sync {
            streamsLabel?.text = "lists stream: \(state)"
        }
    }

    override func on(newEvent event: RawSSE) {
        guard let decoded: ChangeEvent<Document> = try! event.decodeStitchSSE() else {
            return
        }

        DispatchQueue.main.sync {
            let toast = try! rootView?.toastViewForMessage("\(decoded.operationType): \(decoded.documentKey)", title: "lists", image: nil, style: toastStyle)

            rootView?.showToast(toast!)
        }
    }
}

class TodoTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var items: RemoteMongoCollection<TodoItem>!
    private var lists: RemoteMongoCollection<Document>!
    private var userId: String?
    private var todoItems = NSMutableOrderedSet()
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!

    @IBOutlet weak var itemsStream: UILabel!
    @IBOutlet weak var listsStream: UILabel!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.default
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        ToastManager.shared.isQueueEnabled = true
        self.tableView.delegate = self
        self.tableView.dataSource = self

        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                        target: self,
                                        action: #selector(addTodoItem(_:)))
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash,
                                           target: self,
                                           action: #selector(removeAll(_:)))
        self.toolBar.items?.append(addButton)
        self.toolBar.items?.append(deleteButton)
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
                    let index = self.todoItems.index(ofObjectPassingTest: { (todoItem, index, bool) -> Bool in
                        return bsonEquals((todoItem as? TodoItem)?.id, event.documentKey["_id"])
                    })
                    guard index != NSNotFound else {
                        return
                    }
                    self.todoItems.removeObject(at: index)
                } else {
                    self.todoItems.add(event.fullDocument!)
                }

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
                    guard let todos = event.fullDocument?["todos"] as? [BSONValue] else {
                        try! self.items.sync.desync(ids: self.items.sync.syncedIds.map { $0.bsonValue.value })
                        return
                    }
                    DispatchQueue.main.sync {
                        let toast = try! self.view.toastViewForMessage("syncing on new ids: \(todos)", title: nil, image: nil, style: toastStyle)
                        self.view.showToast(toast)
                    }
                    try! self.items.sync.sync(ids: todos)
                }
            },
            errorListener: { (error, _) in
                print(error.localizedDescription)
        })

        let icsd: InstanceChangeStreamDelegate = items
            .sync
            .proxy
            .dataSynchronizer
            .instanceChangeStreamDelegate

        icsd[MongoNamespace(databaseName: todoListsDatabase,
                            collectionName: todoItemsCollection)]?.add(streamDelegate: ItemsStreamDelegate(rootView: self.view, streamsLabel: self.itemsStream))
        icsd[MongoNamespace(databaseName: todoListsDatabase,
                            collectionName: todoListsCollection)]?.add(streamDelegate: ListsStreamDelegate(rootView: self.view, streamsLabel: self.listsStream))

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
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            if let task = alertController.textFields?.first?.text {
                let todoItem = TodoItem.init(id: ObjectId(),
                                             ownerId: self.userId!,
                                             task: task,
                                             checked: false,
                                             doneDate: nil)
                self.items.sync.insertOne(document: todoItem) { result in
                    switch result {
                    case .success(_):
                        self.lists.sync.updateOne(filter: ["_id": self.userId!],
                                                  update: ["$push": ["todos": todoItem.id] as Document],
                                                  options: nil)
                        { result in
                            switch result {
                            case .success(_):
                                if self.todoItems.count == 0 {
                                    self.items
                                        .sync
                                        .proxy
                                        .dataSynchronizer
                                        .instanceChangeStreamDelegate[MongoNamespace(databaseName: todoListsDatabase,
                                                        collectionName: todoItemsCollection)]?.add(streamDelegate: ItemsStreamDelegate(rootView: self.view, streamsLabel: self.itemsStream))
                                }
                                self.todoItems.add(todoItem)
                                DispatchQueue.main.sync {
                                    self.tableView.reloadData()
                                }
                            case .failure(let e):
                                print(e)
                            }
                        }
                    case .failure(let e):
                        fatalError(e.localizedDescription)
                    }

                }
            }
        }))
        self.present(alertController, animated: true)
    }

    @objc func removeAll(_ sender: Any) {
        self.items.deleteMany(["owner_id": userId!]) { result in
            switch result {
            case .failure(let error):
                fatalError(error.localizedDescription)
            default: break
            }
        }
        self.lists.sync.updateOne(filter: ["_id": self.userId!],
                                  update: ["$unset": ["todos": ""] as Document],
                                  options: nil) { result in
            switch result {
            case .failure(let error):
                fatalError(error.localizedDescription)
            default: break
            }
        }
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
                } else {
                    try! self.lists.sync.sync(ids: [self.userId!])
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

