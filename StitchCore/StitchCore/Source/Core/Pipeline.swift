import Foundation
import ExtendedJson

/**
    A pipeline that specifies an action, service, and its arguments.
 */
public struct Pipeline {
    
    private struct Consts {
        static let actionKey =  "action"
        static let serviceKey = "service"
        static let argsKey =    "args"
        static let letKey =     "let"
    }
    
    /**
        The action that represents this stage.
     */
    public let action: String
    /**
     * The service that can handle the action. A null
     * service means that the action is builtin.
     */
    public let service: String?
    /**
     * The arguments to invoke the action with.
     */
    public let args: [String : ExtendedJsonRepresentable]?
    /**
     * The expression to evaluate for use within the arguments via expansion.
     */
    public let `let`: ExtendedJsonRepresentable?
    
    //MARK: - Init
    /**
        Constructs a completely specified pipeline stage
        
        - Parameters:
            - action:  The action that represents this stage.
            - service: The service that can handle the action. A null
                        service means that the action is builtin.
            - args:    The arguments to invoke the action with.
            - let:     The expression to evaluate for use within the arguments via expansion.
     */
    public init(action: String,
                service: String? = nil,
                args: [String : ExtendedJsonRepresentable]? = nil,
                `let`: ExtendedJsonRepresentable? = nil) {
        self.action = action
        self.service = service
        self.args = args
        self.let = `let`
    }
    
    // MARK: - Mapper
    /// Map this pipeline into a Json dict
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
