//
//  BsonSymbol+ExtendedJson.swift
//  ExtendedJson
//
//  Created by Jason Flax on 10/6/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

extension BsonSymbol: ExtendedJsonRepresentable {
    public static func fromExtendedJson(xjson: Any) throws -> ExtendedJsonRepresentable {
        guard let json = xjson as? [String : Any],
            let symbol = json[ExtendedJsonKeys.symbol.rawValue] as? String else {
                throw BsonError.parseValueFailure(value: xjson, attemptedType: BsonSymbol.self)
        }
        
        return BsonSymbol(symbol)
    }
    
    public var toExtendedJson: Any {
        return [ExtendedJsonKeys.symbol.rawValue : self.symbol]
    }
    
    public func isEqual(toOther other: ExtendedJsonRepresentable) -> Bool {
        return other is BsonSymbol && (other as! BsonSymbol).symbol == self.symbol
    }
}
