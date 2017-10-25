import Foundation
import ExtendedJson

// A pipeline that specifies an action, service, and its arguments.
public struct Pipeline: Codable {
    private enum CodingKeys: String, CodingKey {
        case action, service, args, `let`
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
    public let args: BsonDocument?
    /**
     * The expression to evaluate for use within the arguments via expansion.
     */
    public let `let`: BsonDocument?

    // MARK: - Init
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
                args: BsonDocument? = nil,
                `let`: BsonDocument? = nil) {
        self.action = action
        self.service = service
        self.args = args
        self.`let` = `let`
    }
}
