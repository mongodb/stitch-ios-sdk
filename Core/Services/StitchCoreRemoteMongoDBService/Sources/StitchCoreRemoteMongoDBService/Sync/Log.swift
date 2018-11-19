import Foundation
import os

/// Basic compat logger
final class Log {
    /// Tag to prefix log messages
    private let tag: String

    init(tag: String) {
        self.tag = tag
    }

    /// Log info
    func i(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_INFO, tag, msg)
    }

    /// Log debug
    func d(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_DEBUG, tag, msg)
    }

    /// Log error
    func e(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_ERROR, tag, msg)
    }

    /// Log fault
    func f(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_FAULT, tag, msg)
    }

    private func log(_ msg: StaticString,
                     type: OSLogType = __OS_LOG_TYPE_DEFAULT,
                     _ args: CVarArg...) {
        if #available(iOS 10.0, *) {
            os_log(msg, type: type, args)
        } else {
            // Fallback on earlier versions
            print(String.init(format: msg.description, args))
        }
    }
}
