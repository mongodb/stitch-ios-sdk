//
//  Utils.swift
//  StitchCoreTests
//
//  Created by Jason Flax on 2/5/18.
//  Copyright © 2018 MongoDB. All rights reserved.
//

import Foundation
import XCTest
import PromiseKit

open class StitchTestCase: XCTestCase {
    @discardableResult
    func await<T>(_ promise: Promise<T>,
                  function: String = #function,
                  line: Int = #line) -> T? {
        let exp = expectation(description: "#\(function)#\(line)")

        var t: T?

        promise.done {
            t = $0
            exp.fulfill()
        }.catch { err in
            print(err)
            XCTFail(err.localizedDescription)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 10)
        return t
    }
}
