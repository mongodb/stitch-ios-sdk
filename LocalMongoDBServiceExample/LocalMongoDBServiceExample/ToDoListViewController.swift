import MongoMobile
import StitchCore_iOS
import LocalMongoDBService
import Toast_Swift
import UIKit

/// Name of ToDoList db
private let toDoListDatabaseName = "todo"
/// Name of ToDoList collection
private let toDoListCollectionName = "items"
/// Cell reuse id (cells that scroll out of view can be reused)
private let cellReuseIdentifier = "ToDoItemTableViewCell"

/// View Controller for the ToDo List
class ToDoListViewController: UITableViewController {
    private var toDoListCollection: MongoCollection!

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            // try to initialize the default stitch client
            let client =
                try Stitch.initializeDefaultAppClient(
                    withConfigBuilder: StitchAppClientConfigurationBuilder.init {
                        $0.clientAppId = "test-app"
                    })
            // try to get the default mongo client
            let mongoClient = try client.serviceClient(forService: MongoDBService)

            // fetch the toDo list collection
            self.toDoListCollection =
                try mongoClient.db(toDoListDatabaseName).collection(toDoListCollectionName)

            // this view controller itself will provide the delegate
            // methods and row data for the table view.
            tableView.delegate = self
            tableView.dataSource = self
        } catch let err {
            makeToast(self.view,
                      message: "Error initializing MongoMobile: \(err)")
        }
    }

    // create a cell for each table view row
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // create a new cell if needed or reuse an old one
        guard let cell: ToDoItemCell =
            tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                          for: indexPath) as? ToDoItemCell else {
            fatalError("Reusable cell was not a `ToDoItemCell`")
        }

        // set the toDo item from the data model
        do {
            try cell.setToDoItem(withIndex: indexPath.row,
                                 fromCollection: self.toDoListCollection)
        } catch let err {
            self.view.makeToast(
                "Error setting new ToDo item: \(err)",
                duration: 3.0,
                position: .bottom,
                style: ToastStyle()
            )
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        guard let count = try? self.toDoListCollection.count() else {
            return 0
        }

        return count
    }

    @IBAction func addItem(_ sender: Any) {
        let alertController = UIAlertController(title: "Add Task",
                                                message: nil,
                                                preferredStyle: .alert)

        // ADD ACTIONS HANDLER
        let taskAction = UIAlertAction(title: "Add", style: .default) { (_) in
            let taskTextField = alertController.textFields![0] as UITextField

            do {
                var todoItem = TodoItem.init(task: taskTextField.text!)
                try todoItem.save(toCollection: self.toDoListCollection)
                self.tableView.reloadData()
            } catch let err {
                self.view.superview?.makeToast(
                    "Error adding new ToDo item: \(err)",
                    duration: 3.0,
                    position: .bottom,
                    style: ToastStyle()
                )
            }
        }

        taskAction.isEnabled = false
        alertController.addAction(taskAction)

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            // do something
        }
        alertController.addAction(cancelAction)

        // ADD TEXT FIELDS
        alertController.addTextField { textField in
            textField.placeholder = "Task"

            // enable add button when password is entered
            NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextFieldTextDidChange, object: textField, queue: OperationQueue.main) { (notification) in
                taskAction.isEnabled = textField.text != ""
            }
        }

        // PRESENT
        present(alertController, animated: true)
    }

    @IBAction func deleteCompleted(_ sender: Any) {
        let _ = try! self.toDoListCollection.deleteMany(
            [TodoItem.CodingKeys.isCompleted.rawValue: true]
        )
        self.tableView.reloadData()
    }
}

