import Foundation

/**
 * The frequency a user may choose for sync.
 *
 * Configurations should be done using the static initializers for the frequency
 * type of choice, e.g.:
 * sync.configure(frequency: .scheduled(timeInterval: .hours(1), isConnected: true))
 */
public enum SyncFrequency {
    /**
     When a change is made locally or a change from a remote collection is received,
     the Stitch application will react to the event immediately.
     If offline and the change was local, the application will queue the event to
     be synchronized when back online.
     */
    case reactive
    /**
     Local/remote events will be queued on the device for
     a specified amount of time (configurable) before they are applied.
     - parameter timeInterval: the amount of time between syncs.
     - parameter isConnected: whether or not the application continuously applies
                              events by maintaining a sync stream
     */
    case scheduled(timeInterval: DispatchTimeInterval, isConnected: Bool)
    /// The collection will only sync changes when specified by the application.
    case onDemand
}
