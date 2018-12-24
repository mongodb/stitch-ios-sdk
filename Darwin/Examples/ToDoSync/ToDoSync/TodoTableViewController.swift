import UIKit
@testable import StitchCoreRemoteMongoDBService
@testable import StitchRemoteMongoDBService
@testable import StitchCore
@testable import StitchCoreSDK
import MongoSwift
import Toast_Swift
import BEMCheckBox

private var toastStyle: ToastStyle {
    var toastStyle = ToastStyle()
    toastStyle.messageFont = .systemFont(ofSize: 10.0)
    return toastStyle
}

class TodoTableViewController:
    UIViewController, UITableViewDataSource, UITableViewDelegate, ErrorListener {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    private var userId: String? {
        return stitch.auth.currentUser?.id
    }

    private var todoItems = [TodoItem]()

    override func viewDidLoad() {
        super.viewDidLoad()

        ToastManager.shared.isQueueEnabled = true
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.isEditing = true

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                        target: self,
                                        action: #selector(addTodoItem(_:)))
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash,
                                           target: self,
                                           action: #selector(removeAll(_:)))

        self.toolBar.items?.append(addButton)
        self.toolBar.items?.append(flexSpace)
        self.toolBar.items?.append(deleteButton)
        self.toolBar.items?.append(flexSpace)
        self.toolBar.items?.append(UIBarButtonItem.init(customView: BEMCheckBox.init(frame: CGRect.init(x: self.view.frame.maxX - 10, y: self.toolBar.frame.maxY - 10, width: 30, height: 30))))

        if stitch.auth.isLoggedIn {
            loggedIn()
        } else {
            doLogin()
        }
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
                                             doneDate: nil,
                                             index: self.todoItems.count,
                                             checked: false)
                itemsCollection.sync.insertOne(document: todoItem) { result in
                    switch result {
                    case .success(_):
                        listsCollection.sync.updateOne(filter: ["_id": self.userId!],
                                             update: ["$push": ["todos": todoItem.id] as Document],
                                                  options: nil)
                        { result in
                            switch result {
                            case .success(_):
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
        itemsCollection.deleteMany(["owner_id": userId!]) { result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            default: break
            }
        }
        
        listsCollection.sync.updateOne(filter: ["_id": self.userId!],
                                  update: ["$unset": ["todos": ""] as Document],
                                  options: nil) { result in
            switch result {
            case .failure(let error):
                fatalError(error.localizedDescription)
            default: break
            }
        }
    }

    private func loggedIn() {
        // Configure sync to be remote wins on both collections meaning and conflict that occurs should
        // prefer the remote version as the resolution.
        itemsCollection.sync.configure(
            conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict,
            changeEventDelegate: { documentId, event in
                guard let id = event.documentKey["_id"] else {
                    return
                }

                if event.operationType == .delete {
                    guard let idx = self.todoItems.firstIndex(where: { bsonEquals($0.id, id) }) else {
                        return
                    }
                    self.todoItems.remove(at: idx)
                } else {
                    if let index = self.todoItems.firstIndex(where: { bsonEquals($0.id, id) }) {
                        self.todoItems[index] = event.fullDocument!
                    } else {
                        if !itemsCollection.sync.syncedIds.contains(where: { bsonEquals($0.bsonValue.value, id) }) {
                            try! itemsCollection.sync.sync(ids: [id])
                        }
                        self.todoItems.append(event.fullDocument!)
                    }
                }

                DispatchQueue.main.sync {
                    let toast = try! self.view.toastViewForMessage(
                        "\(event.operationType) for item: '\(event.fullDocument?.task ?? "(removed)")'",
                        title: "items",
                        image: nil,
                        style: toastStyle)
                    self.view.showToast(toast)

                    self.todoItems.sort()

                    // if it's a change to the index, it will be handled elsewhere
                    if event.updateDescription?.updatedFields["index"] == nil {
                        self.tableView.reloadData()
                    }
                }
        }, errorListener: self.on)

        listsCollection.sync.configure(
            conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict,
            changeEventDelegate: { documentId, event in
                if !event.hasUncommittedWrites {
                    guard let todos = event.fullDocument?.todos else {
                        self.todoItems.removeAll()
                        DispatchQueue.main.sync {
                            self.tableView.reloadData()
                        }
                        try! itemsCollection.sync.desync(ids: itemsCollection.sync.syncedIds.map { $0.bsonValue.value })
                        return
                    }
                    try! itemsCollection.sync.sync(ids: todos)
                }
        }, errorListener: self.on)

        indexSwapsCollection.sync.configure(
            conflictHandler: DefaultConflictHandlers.remoteWins.resolveConflict,
            changeEventDelegate: { documentId, event in
                guard !event.hasUncommittedWrites,
                    let fromIndex = event.fullDocument?.fromIndex,
                    let toIndex = event.fullDocument?.toIndex,
                    event.fullDocument?.generatedBy != IndexSwap.sessionId else {
                        return
                }

                DispatchQueue.main.sync {
//                    let toast = try! self.view.toastViewForMessage(
//                        "swapping indices: \(fromIndex) -> \(toIndex)",
//                        title: "indexSwaps",
//                        image: nil,
//                        style: toastStyle)
//                    self.view.showToast(toast)
                    self.tableView.moveRow(at: IndexPath(row: fromIndex, section: 0),
                                           to: IndexPath(row: toIndex, section: 0))
                }
        },
            errorListener: self.on)

        itemsCollection.sync.find { result in
            switch result {
            case .success(let todos):
                self.todoItems = todos.map { $0 }.sorted()
                DispatchQueue.main.sync {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    private func doLogin() {
        stitch.auth.login(withCredential:
        ServerAPIKeyCredential(withKey: "CWQMnJNbgekCq62zWMZAabeQtpRWpHDCKLtef7WLqoyHGvNC5Unn65AXloil1HOx")) {
            switch $0 {
            case .success(let user):
                print("logged in")

                if listsCollection.sync.syncedIds.isEmpty {
                    listsCollection.sync.insertOne(document: TodoList(id: user.id)) { _ in }
                }
                if indexSwapsCollection.sync.syncedIds.isEmpty {
                    indexSwapsCollection.sync.insertOne(document: IndexSwap(id: user.id)) { _ in }
                }

                self.loggedIn()
            case .failure(let e):
                print("error logging in \(e)")
            }
        }
    }

    func on(error: Error, forDocumentId documentId: BSONValue?) {
        DispatchQueue.main.sync {
            let toast = try! self.view.toastViewForMessage(
                "\(error)",
                title: nil,
                image: nil,
                style: toastStyle)
            self.view.showToast(toast)
        }
    }

    func tableView(_ tableView: UITableView,
                   shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView,
                   editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView,
                   moveRowAt sourceIndexPath: IndexPath,
                   to destinationIndexPath: IndexPath) {
        let itemToMove = todoItems[sourceIndexPath.row]
        todoItems.remove(at: sourceIndexPath.row)
        todoItems.insert(itemToMove, at: destinationIndexPath.row)
        todoItems.indices.forEach({ index in
            if todoItems[index].index != index {
                todoItems[index].index = index
            }
        })
        todoItems.sort()
        indexSwapsCollection.sync.updateOne(
            filter: ["_id": self.userId],
            update: try! BSONEncoder().encode(
                IndexSwap(id: self.userId!, todoId: itemToMove.id, fromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)), options: nil) { _ in }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return todoItems.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TodoTableViewCell",
                                                 for: indexPath) as! TodoTableViewCell
        cell.set(todoItem: todoItems[indexPath.item])
        return cell
    }
}

