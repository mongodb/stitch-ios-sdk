public protocol EventStream {
    /**
      The next event in this event stream.

      @return next event in this stream
     */
    func nextEvent() throws -> Event

    /**
     * Whether or not the stream is currently open.
     * @return true if open, false if not
     */
    var isOpen: Bool { get }

    /**
     * Close the current stream.
     * @throws IOException can throw exception if internal buffer not closed properly
     */
    func close()

    /**
     * Cancels the underlying connection to the current stream.
     */
    func cancel()

    /**
     * Read the next line of a stream from a given source.
     * @return the next utf8 line
     * @throws IOException if a stream is in the wrong state, IO errors can be thrown
     */
    func readLine() -> String?
}

extension EventStream {
    private func process(value: String,
                         forField field: String,
                         eventName: inout String,
                         dataBuffer: inout String) {
        // If the field name is "event"
        switch (field) {
        case "event":
            eventName = value
            break
        // If the field name is "data"
        case "data":
            // If the data buffer is not the empty string, then append a single U+000A LINE FEED
            // character to the data buffer.
            if dataBuffer.count != 0 {
                dataBuffer += "\n"
            }
            dataBuffer += value
            break
        // If the field name is "id"
        case "id":
            // NOT IMPLEMENTED
            break
        // If the field name is "retry"
        case "retry":
            // NOT IMPLEMENTED
            break
        // Otherwise
        default:
            // The field is ignored.
            break
        }
    }

    /**
     * Process the next event in a given stream.
     * @return the fully processed event
     * @throws IOException if a stream is in the wrong state, IO errors can be thrown
     */
    public func nextEvent() throws -> Event {
        var doneOnce = false
        var dataBuffer = ""
        var eventName = ""
        while true {
            guard let line = readLine() else {
                if doneOnce {
                    throw StitchError.clientError(
                        withClientErrorCode: StitchClientErrorCode.couldNotLoadPersistedAuthInfo)
                }
                doneOnce = true
                continue
            }

            // If the line is empty (a blank line), Dispatch the event, as defined below.
            if line.isEmpty {
                // If the data buffer is an empty string, set the data buffer and the event name buffer to
                // the empty string and abort these steps.
                if (dataBuffer.count == 0) {
                    eventName = ""
                    continue
                }

                // If the event name buffer is not the empty string but is also not a valid NCName,
                // set the data buffer and the event name buffer to the empty string and abort these steps.
                // NOT IMPLEMENTED
                return Event.init(data: dataBuffer, eventName: eventName)
            // If the line starts with a U+003A COLON character (':')
            } else if line.starts(with: ":") {
                // ignore the line
                // If the line contains a U+003A COLON character (':') character
            } else if line.contains(":") {
                // Collect the characters on the line before the first U+003A COLON character (':'),
                // and let field be that string.
                let colonIdx = line.firstIndex(of: ":")!
                let field = line[line.startIndex ..< colonIdx]

                // Collect the characters on the line after the first U+003A COLON character (':'),
                // and let value be that string.
                // If value starts with a single U+0020 SPACE character, remove it from value.
                var value = line[line.index(after: colonIdx) ..< line.endIndex]
                value = value.starts(with: " ") ? value.dropFirst() : value

                process(value: String(value), forField: String(field), eventName: &eventName, dataBuffer: &dataBuffer)
                // Otherwise, the string is not empty but does not contain a U+003A COLON character (':')
                // character
            } else {
                process(value: "", forField: line, eventName: &eventName, dataBuffer: &dataBuffer)
            }
        }
    }
}
