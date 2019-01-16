import MongoSwift

/**
 TODO: Once SWIFT-255 is complete, remove these functions
 */
func validateBSONTypes(_ lhs: BSONValue, _ rhs: BSONValue) {
    let invalidTypes: [BSONType] = [.symbol, .dbPointer, .invalid, .undefined, .null]
    guard !invalidTypes.contains(lhs.bsonType) else {
        preconditionFailure("\(lhs.bsonType) should not be used")
    }
    guard !invalidTypes.contains(rhs.bsonType) else {
        preconditionFailure("\(rhs.bsonType) should not be used")
    }
}

// swiftlint:disable identifier_name
// swiftlint:disable cyclomatic_complexity
func bsonEqualsOverride(_ lhs: BSONValue?, _ rhs: BSONValue?) -> Bool {
    if lhs == nil && rhs == nil {
        return true
    }

    if (lhs != nil && rhs == nil) || (rhs != nil && lhs == nil) {
        return false
    }

    guard let lhs = lhs, let rhs = rhs else {
        return false
    }

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
        return l.count == r.count && zip(l, r).reduce(true, {prev, next in bsonEqualsOverride(next.0, next.1) && prev})
    case (_ as [Any], _ as [Any]): return false
    default: return false
    }
}
// swiftlint:enable identifier_name

/**
 TODO: Remove this class entirely once the Swift Driver
 conforms to Hashable/Equatable
 */
private func _hash(into hasher: inout Hasher, bsonValue: BSONValue?) {
    switch bsonValue {
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
// swiftlint:enable cyclomatic_complexity

extension BSONValue {
    func hash(into hasher: inout Hasher) {
        _hash(into: &hasher, bsonValue: self)
    }
}

extension AnyBSONValue: Hashable {
    public static func == (lhs: AnyBSONValue, rhs: AnyBSONValue) -> Bool {
        return bsonEquals(lhs.value, rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        _hash(into: &hasher, bsonValue: self.value)
    }
}
public struct HashableBSONValue: Codable, Hashable {
    public let bsonValue: AnyBSONValue
    var value: BSONValue {
        return bsonValue.value
    }
    public init(_ bsonValue: BSONValue) {
        self.bsonValue = AnyBSONValue(bsonValue)
    }

    public init(_ anyBSONValue: AnyBSONValue) {
        self.bsonValue = anyBSONValue
    }

    // TODO(STITCH-2329): These swiftlint disables should go away because we should not be force trying
    // swiftlint:disable force_try
    public init(from decoder: Decoder) {
        bsonValue = try! AnyBSONValue.init(from: decoder)
    }

    public func encode(to encoder: Encoder) {
        try! bsonValue.encode(to: encoder)
    }
    // swiftlint:enable force_try

    public static func == (lhs: HashableBSONValue, rhs: HashableBSONValue) -> Bool {
        return bsonEqualsOverride(lhs.bsonValue.value, rhs.bsonValue.value)
    }

    public func hash(into hasher: inout Hasher) {
        _hash(into: &hasher, bsonValue: self.bsonValue.value)
    }
}
