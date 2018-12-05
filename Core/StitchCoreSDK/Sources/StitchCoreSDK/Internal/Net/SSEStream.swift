import Foundation

public class SSEStream<T: Decodable>: RawSSEStream {
    override init() {
        super.init()
    }
    public override func nextEvent() throws -> SSE<T> {
        let nextEvent = try super.nextEvent()
        guard let sse = try SSE<T>(rawData: nextEvent.rawData,
                                   eventName: nextEvent.eventName) else {
            // drop the nil event. we don't want to expose these
            return try self.nextEvent()
        }
        return sse
    }
}
