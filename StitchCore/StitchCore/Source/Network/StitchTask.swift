import Foundation

/// Promise system to handle requests to Stitch
open class StitchTask<Result> {
    
    private let queue: OperationQueue
    
    /// The final result of this task
    public var result: StitchResult<Result>? {
        didSet{
            queue.isSuspended = false
        }
    }
    
    // MARK: - Init
    
    /// Create a new `StitchTask`
    public init() {
        queue = {
            let operationQueue = OperationQueue()
            
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.isSuspended = true
            operationQueue.qualityOfService = .utility
            
            return operationQueue
        }()
    }
    
    /**
        Create a new `StitchTask`
 
        - parameter error: Error to be deferred to in the event of failure
    */
    public convenience init(error: Error) {
        self.init()
        
        // this call is done within `defer` to make sure the `didSet` observers gets called, since observers are not called when a property is first initialized
        defer {
            result = .failure(error)
        }
    }
    
    // MARK: - Public
    
    /**
        Fetch the response asynchronously.
 
        - Parameters:
            - queue: Optional `DispatchQueue` if not the main `DispatchQueue`
            - completionHandler: Closure containing the `StitchResult` of this task
 
        - Returns: This task to continue working with.
    */
    @discardableResult
    public func response(onQueue queue: DispatchQueue? = nil, completionHandler: @escaping (_ result: StitchResult<Result>) -> Swift.Void) -> StitchTask<Result> {
        self.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                completionHandler(self.result!)
            }
        }
        return self
    }
    
}

// MARK: - Continuation Task

extension StitchTask {
    /**
        Continue this task with a new Task that will be completed with the result of
        applying the specified continuation to this `StitchTask`.
 
        - parameter oldResult: Result of the previous task
        - Returns: a new Task that will be completed with the result of
                        applying the specified continuation
     */
    @discardableResult
    public func continuationTask<NewResultType>(parser: @escaping (_ oldResult: Result) throws -> NewResultType) -> StitchTask<NewResultType>{
        let newTask = StitchTask<NewResultType>()
        response(onQueue: DispatchQueue.global(qos: .utility)) { (stitchResult: StitchResult<Result>) in
            switch stitchResult {
            case .success(let oldResult):
                do {
                    let newResult = try parser(oldResult)
                    newTask.result = .success(newResult)
                }
                catch {
                    newTask.result = .failure(error)
                }
                break
            case .failure(let error):
                newTask.result = .failure(error)
                break
            }
        }
        return newTask
    }
    
}


/// Generic results structure that contains success and failure values.
public enum StitchResult<Value> {
    /// If the Task was successful with a value
    case success(Value)
    /// If the Task failed with a value
    case failure(Error)
    
    /// Value from the `StitchTask` in the event of success
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// Error from the `StitchTask` in the event of failure
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
