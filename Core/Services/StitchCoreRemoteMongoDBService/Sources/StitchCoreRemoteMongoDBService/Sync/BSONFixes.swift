import MongoSwift

func validateBSONTypes(_ lhs: BSONValue, _ rhs: BSONValue) {
    let invalidTypes: [BSONType] = [.symbol, .dbPointer, .invalid, .undefined, .null]
    guard !invalidTypes.contains(lhs.bsonType) else {
        preconditionFailure("\(lhs.bsonType) should not be used")
    }
    guard !invalidTypes.contains(rhs.bsonType) else {
        preconditionFailure("\(rhs.bsonType) should not be used")
    }
}

func bsonEquals(_ lhs: BSONValue, _ rhs: BSONValue) -> Bool {
    validateBSONTypes(lhs, rhs)

    switch (lhs, rhs) {
    case (let l as Int, let r as Int): return l == r
    case (let l as Int32, let r as Int32): return l == r
    case (let l as Int64, let r as Int64): return l == r
    case (let l as Double, let r as Double): return l == r
    case (let l as Decimal128, let r as Decimal128): return l == r
    case (let l as Bool, let r as Bool): return l == r
    case (let l as String, let r as String): return l == r
    case (let l as RegularExpression, let r as RegularExpression): return l == r
    case (let l as Timestamp, let r as Timestamp): return l == r
    case (let l as Date, let r as Date): return l == r
    case (_ as MinKey, _ as MinKey): return true
    case (_ as MaxKey, _ as MaxKey): return true
    case (let l as ObjectId, let r as ObjectId): return l == r
    case (let l as CodeWithScope, let r as CodeWithScope): return l == r
    case (let l as Binary, let r as Binary): return l == r
    case (let l as Document, let r as Document):
        return l == r
    case (let l as [BSONValue?], let r as [BSONValue?]):
        return l.count == r.count && zip(l, r).reduce(true, {prev, next in bsonEquals(next.0, next.1) && prev})
    case (_ as [Any], _ as [Any]): return false
    default: return false
    }
}
