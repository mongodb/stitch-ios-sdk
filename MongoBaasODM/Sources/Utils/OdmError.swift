//
//  OdmError.swift
//  MongoBaasODM
//
//  Created by Miko Halevi on 4/26/17.
//  Copyright © 2017 MongoDB. All rights reserved.
//

import Foundation

public enum OdmError: Error {
    case objectIdNotFound
    case classMetaDataNotFound
    case corruptedData(message: String)
    case updateParametersMissing
    case collectionOutOfRange
}

// MARK: - Error Descriptions

extension OdmError: LocalizedError {
    public var errorDescription: String {
        switch self {
        case .objectIdNotFound:
            return "no objectId found for the Entity"
        case .classMetaDataNotFound:
            return "Could not find class metadata, the class is not registerd with the right name"
        case .corruptedData(let message):
            return message
        case .updateParametersMissing:
            return "parameters missing for update operation"
        case .collectionOutOfRange:
            return "No more results are available"
        }
    }
}
