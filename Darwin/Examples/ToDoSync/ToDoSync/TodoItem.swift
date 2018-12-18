import MongoSwift

/** A todo item from a MongoDB document. */
struct TodoItem: Codable, Hashable {
    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        return bsonEquals(lhs.id, rhs.id)
    }

    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case ownerId = "owner_id"
        case task, checked
        case doneDate = "done_date"
    }

    let id: ObjectId
    let ownerId: String
    let task: String
    let checked: Bool
    let doneDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id.oid)
    }
}
