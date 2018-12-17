public class DataSynchronizerError: Error, CustomStringConvertible {
    public var description: String

    public init (_ msg: String) {
        self.description = msg
    }
}
