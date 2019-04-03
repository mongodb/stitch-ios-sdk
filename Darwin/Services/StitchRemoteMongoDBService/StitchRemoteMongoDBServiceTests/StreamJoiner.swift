// swiftlint:disable force_try
import MongoSwift
import StitchCoreSDK
import StitchCoreRemoteMongoDBService

internal class StreamJoiner: SSEStreamDelegate {
    var events = [ChangeEvent<Document>]()
    var streamState: SSEStreamState?

    override func on(stateChangedFor state: SSEStreamState) {
        streamState = state
    }

    override func on(newEvent event: RawSSE) {
        guard let changeEvent: ChangeEvent<Document> = try! event.decodeStitchSSE() else {
            return
        }

        events.append(changeEvent)
    }

    func wait(forState state: SSEStreamState) {
        let semaphore = DispatchSemaphore.init(value: 0)
        DispatchWorkItem {
            while self.streamState != state {
                usleep(100)
            }
            semaphore.signal()
            }.perform()
        _ = semaphore.wait(timeout: .init(uptimeNanoseconds: UInt64(1e+10)))
    }

    func wait(forEvents eventCount: Int) {
        let semaphore = DispatchSemaphore.init(value: 0)
        DispatchWorkItem {
            while self.events.count < eventCount {
                usleep(100)
            }
            semaphore.signal()
            }.perform()
        _ = semaphore.wait(timeout: .init(uptimeNanoseconds: UInt64(1e+10)))
    }

    func clearEvents() {
        events.removeAll()
    }
}
