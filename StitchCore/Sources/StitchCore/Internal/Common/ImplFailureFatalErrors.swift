/**
 * Invokes `fatalError` to indicate that the function called was not implemented. Never returns, and always crashes the
 * application.
 */
func notImplemented(_ file: String = #function) -> Never {
    fatalError("\(file) not implemented")
}
