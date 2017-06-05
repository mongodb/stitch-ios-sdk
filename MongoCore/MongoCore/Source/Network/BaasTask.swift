//
//  BaasTask.swift
//  MongoCore
//
//  Created by Ofer Meroz on 02/02/2017.
//  Copyright © 2017 Zemingo. All rights reserved.
//

import Foundation

open class BaasTask<Result> {
    
    private let queue: OperationQueue
    
    internal var result: BaasResult<Result>? {
        didSet{
            queue.isSuspended = false
        }
    }
    
    // MARK: - Init
    
    internal init() {
        queue = {
            let operationQueue = OperationQueue()
            
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.isSuspended = true
            operationQueue.qualityOfService = .utility
            
            return operationQueue
        }()
    }
    
    public convenience init(error: Error) {
        self.init()
        
        // this call is done within `defer` to make sure the `didSet` observers gets called, since observers are not called when a property is first initialized
        defer {
            result = .failure(error)
        }
    }
    
    // MARK: - Public
    
    @discardableResult
    public func response(onQueue queue: DispatchQueue? = nil, completionHandler: @escaping (_ result: BaasResult<Result>) -> Swift.Void) -> BaasTask<Result> {
        self.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                completionHandler(self.result!)
            }
        }
        return self
    }
    
}

// MARK: - Continuation Task

extension BaasTask {
    
    @discardableResult
    public func continuationTask<NewResultType>(parser: @escaping (_ oldResult: Result) throws -> NewResultType) -> BaasTask<NewResultType>{
        let newTask = BaasTask<NewResultType>()
        response(onQueue: DispatchQueue.global(qos: .utility)) { (baasResult: BaasResult<Result>) in
            switch baasResult {
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

public enum BaasResult<Value> {
    case success(Value)
    case failure(Error)
    
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
    
}

