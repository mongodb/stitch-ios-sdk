import Foundation
import MongoSwift
/**
 TODO: Remove this class entirely once the Swift Driver
 conforms to Hashable/Equatable
*/
private func _hash(into hasher: inout Hasher, bsonValue: BSONValue?) {
    switch (bsonValue) {
    case (let value as Int):
        hasher.combine(value)
    case (let value as Int32):
        hasher.combine(value)
    case (let value as Int64):
        hasher.combine(value)
    case (let value as Double):
        hasher.combine(value)
    case (let value as Decimal128):
        hasher.combine(value.data)
    case (let value as Bool):
        hasher.combine(value)
    case (let value as String):
        hasher.combine(value)
    case (let value as RegularExpression):
        hasher.combine(value.options)
        hasher.combine(value.pattern)
    case (let value as Timestamp):
        hasher.combine(value.timestamp)
    case (let value as Date):
        hasher.combine(value.timeIntervalSince1970)
    case (_ as MinKey):
        hasher.combine(1)
    case (_ as MaxKey):
        hasher.combine(1)
    case (let value as ObjectId):
        hasher.combine(value.description)
    case (let value as CodeWithScope):
        hasher.combine(value.code)
        _hash(into: &hasher, bsonValue: value.scope)
    case (let value as Binary):
        hasher.combine(value.data)
    case (let value as Document):
        hasher.combine(value.canonicalExtendedJSON)
    case (let value as [BSONValue?]): // TODO: SWIFT-242
        return value.forEach { _hash(into: &hasher, bsonValue: $0!) }
    default: break
    }
}

extension BSONValue {
    func hash(into hasher: inout Hasher) {
        _hash(into: &hasher, bsonValue: self)
    }
}

struct HashableBSONValue: Codable, Hashable {
    let bsonValue: AnyBSONValue

    init(_ bsonValue: BSONValue) {
        self.bsonValue = AnyBSONValue(bsonValue)
    }

    init(_ anyBSONValue: AnyBSONValue) {
        self.bsonValue = anyBSONValue
    }

    init(from decoder: Decoder) {
        bsonValue = try! AnyBSONValue.init(from: decoder)
    }

    func encode(to encoder: Encoder) {
        try! bsonValue.encode(to: encoder)
    }

    static func == (lhs: HashableBSONValue, rhs: HashableBSONValue) -> Bool {
        return bsonEquals(lhs.bsonValue.value, rhs.bsonValue.value)
    }

    func hash(into hasher: inout Hasher) {
        _hash(into: &hasher, bsonValue: self.bsonValue.value)
    }
}
