import MongoSwift

/*
 * Implementation of FNV-1a hash algorithm.
 * See: https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
 */
class HashUtils {
    private static let FNV64BitOffsetBasis: Int64 = -3750763034362895579
    private static let FNV64BitPrime: Int64 = 1099511628211

    static func hash(doc: Document?) -> Int64 {
        if let docBytes: Data = doc?.rawBSON {
            var hashValue: Int64 = FNV64BitOffsetBasis

            for byte in docBytes {
                hashValue ^= Int64(byte)
                hashValue &*= FNV64BitPrime
            }

            return hashValue
        }

        return 0
    }
}
