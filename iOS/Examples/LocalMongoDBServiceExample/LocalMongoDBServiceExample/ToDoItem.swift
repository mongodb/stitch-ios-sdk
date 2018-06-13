import Foundation
import MongoMobile

struct TodoItem {
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case taskDescription
        case isCompleted
        case doneDate = "done_date"
    }

    /// Description of this task
    let taskDescription: String
    /// Whether or not the task has been completed
    private(set) var isCompleted: Bool = false
    /// Unique id of this todo item
    private var id: ObjectId?
    /// When the task was completed
    private var doneDate: Date?

    init(task: String) {
        self.taskDescription = task
        self.doneDate = nil
        self.id = nil
    }

    init(from document: Document) throws {
        self.id = document[CodingKeys.id.rawValue] as? ObjectId
        self.taskDescription = document[CodingKeys.taskDescription.rawValue] as! String
        self.isCompleted = document[CodingKeys.isCompleted.rawValue] as! Bool
        self.doneDate = document[CodingKeys.doneDate.rawValue] as? Date
    }

    @discardableResult
    mutating func set(completed: Bool,
                      toCollection collection: MongoCollection) throws -> ObjectId {
        self.isCompleted = completed
        self.doneDate = completed ? Date() : nil
        return try save(toCollection: collection)
    }

    @discardableResult
    mutating func save(toCollection collection: MongoCollection) throws -> ObjectId {
        let doc = Document([
            CodingKeys.taskDescription.rawValue: taskDescription,
            CodingKeys.isCompleted.rawValue: isCompleted,
            CodingKeys.doneDate.rawValue: doneDate
        ])

        if let id = self.id {
            let _ = try collection.replaceOne(filter: [ "_id": id ] as Document,
                                              replacement: doc)
        } else {
            let result = try collection.insertOne(doc)
            self.id = result?.insertedId as? ObjectId
        }

        return self.id!
    }
}
