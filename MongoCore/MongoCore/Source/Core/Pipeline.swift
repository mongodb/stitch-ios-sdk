//
//  Pipeline.swift
//  MongoCore
//
//  Created by Ofer Meroz on 09/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation
import MongoExtendedJson

public struct Pipeline {
    
    private struct Consts {
        static let actionKey =  "action"
        static let serviceKey = "service"
        static let argsKey =    "args"
        static let letKey =     "let"
    }
    
    public let action: String
    public let service: String?
    public let args: [String : JsonExtendable]?
    public let `let`: JsonExtendable?
    
    //MARK: - Init
    
    public init(action: String, service: String? = nil, args: [String : JsonExtendable]? = nil, `let`: JsonExtendable? = nil) {
        self.action = action
        self.service = service
        self.args = args
        self.let = `let`
    }
    
    // MARK: - Mapper
        
    internal var toJson: [String : Any] {
        
        var json: [String : Any] = [Consts.actionKey : action]
        
        if let service = service {
            json[Consts.serviceKey] = service
        }
        
        if let args = args {            
            json[Consts.argsKey] = args.reduce([:], { (result, pair) -> [String : Any] in
                var res = result
                res[pair.key] = pair.value.toExtendedJson
                return res
            })
        }
        
        if let `let` = `let` {
            json[Consts.letKey] = `let`.toExtendedJson
        }
        
        return json
    }
}
