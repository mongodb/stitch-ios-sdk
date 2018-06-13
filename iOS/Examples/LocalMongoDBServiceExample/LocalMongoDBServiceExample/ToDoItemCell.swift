import MongoMobile
import Toast_Swift
import UIKit

class ToDoItemCell: UITableViewCell {
    @IBOutlet private weak var taskLabel: UILabel!
    @IBOutlet private weak var completedSwitch: UISwitch!

    private var toDoItem: TodoItem!
    private weak var collection: MongoCollection!

    func setToDoItem(withIndex index: Int,
                     fromCollection collection: MongoCollection) throws {
        let document = try collection.find().map { $0 }[index]
        self.toDoItem = try TodoItem.init(from: document)
        self.collection = collection

        self.updateLabel()
        self.completedSwitch.setOn(self.toDoItem!.isCompleted, animated: false)
    }

    @IBAction func switched(_ sender: Any) {
        do {
            try self.toDoItem?.set(completed: self.completedSwitch.isOn,
                                   toCollection: self.collection)
            updateLabel()
        } catch let err {
            self.contentView.makeToast(
                "Error completing ToDo item: \(err)",
                duration: 3.0,
                position: .bottom,
                style: ToastStyle()
            )
        }
    }

    private func updateLabel() {
        guard let toDoItem = self.toDoItem else {
            return
        }

        let attributeString: NSMutableAttributedString =
            NSMutableAttributedString(string: toDoItem.taskDescription)

        if toDoItem.isCompleted {
            attributeString.addAttribute(NSAttributedStringKey.strikethroughStyle,
                                         value: 2,
                                         range: NSMakeRange(0, attributeString.length))
        }

        taskLabel.attributedText = attributeString
    }
}
