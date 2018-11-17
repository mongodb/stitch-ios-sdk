import Foundation
import os

class Log {
    private let tag: String

    init(tag: String) {
        self.tag = tag
    }

    func i(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_INFO, tag, msg)
    }

    func d(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_DEBUG, tag, msg)
    }

    func e(_ msg: String) {
        log("%@: %@", type: __OS_LOG_TYPE_ERROR, tag, msg)
    }

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
