//
//  JsonExtendable.swift
//  MongoExtendedJson
//
//  Created by Ofer Meroz on 16/02/2017.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public protocol JsonExtendable {
    var toExtendedJson: Any {get}
}

extension ObjectId: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.objectid) : hexString]
    }
}

extension String: JsonExtendable {
    
    public var toExtendedJson: Any {
        return self
    }
}

extension Int: JsonExtendable {
    
    public var toExtendedJson: Any {
        // check if we're on a 32-bit or 64-bit platform and act accordingly 
        if MemoryLayout<Int>.size == MemoryLayout<Int32>.size {
            let int32: Int32 = Int32(self)
            return int32.toExtendedJson
        }
        
        let int64: Int64 = Int64(self)
        return int64.toExtendedJson
    }
}

extension Int32: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.numberInt) : String(self)]
    }
}

extension Int64: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.numberLong) : String(self)]
    }
}

extension Double: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.numberDouble) : String(self)]
    }
}

extension BsonBinary: JsonExtendable {
    
    public var toExtendedJson: Any {
        let base64String = Data(bytes: data).base64EncodedString()
        let type = String(self.type.rawValue, radix: 16)
        return [String(describing: ExtendedJsonKeys.binary) : base64String, String(describing: ExtendedJsonKeys.type) : "0x\(type)"]
    }
}

extension Document: JsonExtendable {
    
    //Documen't `makeIterator()` has is no concurency handling, therefor modifying the Document while itereting over it might cause unexpected behaviour
    public var toExtendedJson: Any {        
        return reduce([:]) { (result, dic) -> [String : Any] in
            var result = result
            result[dic.key] = dic.value.toExtendedJson
            return result
        }
    }
}

extension BsonTimestamp: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.timestamp) : String(UInt64(self.time.timeIntervalSince1970))]
    }
}

extension NSRegularExpression: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.regex) : pattern, String(describing: ExtendedJsonKeys.options) : options.toExtendedJson]
    }
}

extension Date: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.date) : [String(describing: ExtendedJsonKeys.numberLong) : String(Int64(timeIntervalSince1970 * 1000))]]
    }
}

extension MinKey: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.minKey) : 1]
    }
}

extension MaxKey: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.maxKey) : 1]
    }
}

extension BsonUndefined: JsonExtendable {
    
    public var toExtendedJson: Any {
        return [String(describing: ExtendedJsonKeys.undefined) : true]
    }
}

extension BsonArray: JsonExtendable {
    
    public var toExtendedJson: Any {
        return map{$0.toExtendedJson}
    }
}

extension Bool: JsonExtendable {
    
    public var toExtendedJson: Any {
        return self
    }
}

extension NSNull: JsonExtendable {
    
    public var toExtendedJson: Any {
        return self
    }
}

// MARK: - Helpers

internal enum ExtendedJsonKeys: CustomStringConvertible {
    case objectid, numberInt, numberLong, numberDouble, date, binary, type, timestamp, regex, options, minKey, maxKey, undefined
    
    var description: String {
        switch self {
        case .objectid:
            return "$oid"
        case .numberInt:
            return "$numberInt"
        case .numberLong:
            return "$numberLong"
        case .numberDouble:
            return "$numberDouble"
        case .date:
            return "$date"
        case .binary:
            return "$binary"
        case .type:
            return "$type"
        case .timestamp:
            return "$timestamp"
        case .regex:
            return "$regex"
        case .options:
            return "$options"
        case .minKey:
            return "$minKey"
        case .maxKey:
            return "$maxKey"
        case .undefined:
            return "$undefined"
            
        }
    }
}

extension NSRegularExpression.Options {
    
    private struct ExtendedJsonOptions {
        static let caseInsensitive =            "i"
        static let anchorsMatchLines =          "m"
        static let dotMatchesLineSeparators =   "s"
        static let allowCommentsAndWhitespace = "x"
    }
    
    internal var toExtendedJson: Any {
        var description = ""
        if contains(.caseInsensitive) {
            description.append(ExtendedJsonOptions.caseInsensitive)
        }
        if contains(.anchorsMatchLines) {
            description.append(ExtendedJsonOptions.anchorsMatchLines)
        }
        if contains(.dotMatchesLineSeparators) {
            description.append(ExtendedJsonOptions.dotMatchesLineSeparators)
        }
        if contains(.allowCommentsAndWhitespace) {
            description.append(ExtendedJsonOptions.allowCommentsAndWhitespace)
        }
        
        return description
    }
    
    internal init(extendedJsonString: String) {
        self = []
        if extendedJsonString.contains(ExtendedJsonOptions.caseInsensitive) {
            self.insert(.caseInsensitive)
        }
        if extendedJsonString.contains(ExtendedJsonOptions.anchorsMatchLines) {
            self.insert(.anchorsMatchLines)
        }
        if extendedJsonString.contains(ExtendedJsonOptions.dotMatchesLineSeparators) {
            self.insert(.dotMatchesLineSeparators)
        }
        if extendedJsonString.contains(ExtendedJsonOptions.allowCommentsAndWhitespace) {
            self.insert(.allowCommentsAndWhitespace)
        }
    }
}

// MARK: ISO8601

internal extension DateFormatter {
    
    static let iso8601DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}
