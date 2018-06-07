import Foundation

public class FunctionSpyUnit { // takes no args
    public init() { }
    
    public private(set) var invocations: Int = 0
    
    public func verify(numberOfInvocations: Int) -> Bool {
        return self.invocations == numberOfInvocations
    }
    
    public func run() {
        self.invocations += 1
    }
    
    public func clearInvocations() {
        self.invocations = 0
    }
}

public class FunctionSpyUnitOneArg<Arg1T> { // takes one arg
    public init() { }
    
    public private(set) var capturedInvocations: [Arg1T] = []
    
    public func verify(numberOfInvocations: Int, forArg matcher: Matcher<Arg1T>) -> Bool {
        switch matcher {
            
        case .any:
            return capturedInvocations.count == numberOfInvocations
        case .with(let condition):
            return capturedInvocations.count(where: { (arg) -> Bool in
                return condition(arg)
            }) == numberOfInvocations
        }
    }
    
    public func run(arg1: Arg1T) {
        capturedInvocations.append(arg1)
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}

public class FunctionSpyUnitTwoArgs<Arg1T, Arg2T> { // takes two args
    public init() { }
    
    public private(set) var capturedInvocations: [(Arg1T, Arg2T)] = []
    
    public func verify(numberOfInvocations: Int, forArg1 matcher1: Matcher<Arg1T>, forArg2 matcher2: Matcher<Arg2T>) -> Bool {
        var count: Int = 0
        
        capturedInvocations.forEach { (argsTuple) in
            let (arg1, arg2) = argsTuple
            var matched1, matched2: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            
            if matched1 && matched2 {
                count += 1
            }
        }
        
        return count == numberOfInvocations
    }
    
    public func run(arg1: Arg1T, arg2: Arg2T) {
        capturedInvocations.append((arg1, arg2))
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}

public class FunctionSpyUnitThreeArgs<Arg1T, Arg2T, Arg3T> { // takes three args
    public init() { }
    
    public private(set) var capturedInvocations: [(Arg1T, Arg2T, Arg3T)] = []
    
    public func verify(numberOfInvocations: Int,
                       forArg1 matcher1: Matcher<Arg1T>,
                       forArg2 matcher2: Matcher<Arg2T>,
                       forArg3 matcher3: Matcher<Arg3T>) -> Bool {
        var count: Int = 0
        
        capturedInvocations.forEach { (argsTuple) in
            let (arg1, arg2, arg3) = argsTuple
            var matched1, matched2, matched3: Bool
            switch matcher1 {
            case .any:
                matched1 = true
            case .with(let condition):
                matched1 = condition(arg1)
            }
            switch matcher2 {
            case .any:
                matched2 = true
            case .with(let condition):
                matched2 = condition(arg2)
            }
            switch matcher3 {
            case .any:
                matched3 = true
            case .with(let condition):
                matched3 = condition(arg3)
            }
            
            if matched1 && matched2 && matched3 {
                count += 1
            }
        }
        
        return count == numberOfInvocations
    }
    
    public func run(arg1: Arg1T, arg2: Arg2T, arg3: Arg3T) {
        capturedInvocations.append((arg1, arg2, arg3))
    }
    
    public func clearInvocations() {
        self.capturedInvocations = []
    }
}
