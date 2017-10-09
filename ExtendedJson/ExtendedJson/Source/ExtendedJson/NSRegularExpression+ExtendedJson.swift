//
//  NSRegularExpression+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/3/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension NSRegularExpression: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let regex = json[ExtendedJsonKeys.regex.rawValue] as? [String : String],
            let pattern = regex["pattern"],
            let options = regex["options"],
            let regularExpression = try? NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options(options)) else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: NSRegularExpression.self)
        }
        
        return regularExpression
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        if let other = other as? NSRegularExpression {
            return self.pattern == other.pattern &&
                self.options == other.options
        }
        return false
        
    }
    
    public var toExtendedJson: Any {
        return [
            ExtendedJsonKeys.regex.rawValue : [
                "pattern": pattern,
                "options": options.toExtendedJson
            ]
        ]
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
    
    internal init(_ extendedJsonString: String) {
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
