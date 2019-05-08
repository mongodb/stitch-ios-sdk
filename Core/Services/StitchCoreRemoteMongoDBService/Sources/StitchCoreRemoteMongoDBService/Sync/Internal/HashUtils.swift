import MongoSwift

/*
 * Implementation of FNV-1a hash algorithm.
 * See: https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function
 */
class HashUtils {
    private static let FNV64BitOffsetBasis: UInt64 = 14695981039346656037
    private static let FNV64BitPrime: UInt64 = 1099511628211

    static func hash(doc: Document?) -> UInt64 {
        if let docBytes: Data = doc?.rawBSON {
            var hashValue: UInt64 = FNV64BitOffsetBasis

            for byte in docBytes {
                hashValue ^= UInt64(byte)
                hashValue &*= FNV64BitPrime
            }

            return hashValue
        }

        return 0
    }
}
