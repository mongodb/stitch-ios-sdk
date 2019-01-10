/// A set of errors that can occur during the synchronization process.
public enum DataSynchronizerError: Error, CustomStringConvertible {
    /**
        Any error related to decoding a document
        This will likely be due to a malformed sync version
        or an unsupported change event.
    */
    case decodingError(_ message: String)
    /**
        An unsupported sync protocol version has been
        supplied with a document. The error message
        contains the faulty version.
    */
    case unsupportedProtocolVersion(_ message: String)
    /**
        Any error related to trying to operate
        on a document that does not exist.
        This can occur if a change event is sent to us
        with missing data, or if a a local document
        is deleted during a replace or update.
     */
    case documentDoesNotExist(_ message: String)
    /**
        Any unexpected mongoDB error. Certain errors
        during the syncing process are expected and will
        create conflicts (e.g., inserting on the same _id)
        but errors outside of the scope of what we can handle
        will be thrown here
    */
    case mongoDBError(_ message: String, _ error: Error)
    /**
        Any error that occurs during the resolution of
        a conflict. Generally, these will be issues
        that occur in the user's delegate class or
        callback.
    */
    case resolutionError(_ error: Error)
    /**
        A special type of error related to irrecoverable
        issues during the synchronization process. This
        will stop the DataSynchronizer.
    */
    case fatalError(_ error: Error)

    public var description: String {
        switch self {
        case .decodingError(let msg):
            return msg
        case .fatalError(let err):
            return err.localizedDescription
        case .unsupportedProtocolVersion(let msg):
            return msg
        case .documentDoesNotExist(let msg):
            return msg
        case .mongoDBError(let msg, let error):
            return "\(msg)::\(error.localizedDescription)"
        case .resolutionError(let err):
            return err.localizedDescription
        }
    }

    public var localizedDescription: String {
        return description
    }
}
