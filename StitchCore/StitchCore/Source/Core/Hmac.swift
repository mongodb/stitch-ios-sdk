//
//  Sha5.swift
//  StitchCore
//
//  Created by Jason Flax on 11/30/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation
import CommonCrypto

internal enum HmacError: Error {
    case encoding(msg: String)
}

internal extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    func base64URLEncodedString() -> String {
        // use URL safe encoding and remove padding
        return self.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}

internal enum Hmac {
    case sha256(data: String, key: String)

    func digest() throws -> Data {
        switch self {
        case .sha256(let data, let key):
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                   key,
                   key.count,
                   data,
                   data.count,
                   &hash)
            return Data(bytes: hash)
        }
    }
}
