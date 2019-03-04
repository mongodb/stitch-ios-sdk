import Foundation

/**
 * A slightly enhanced version of the Foundation `DispatchGroup`, with the added ability to
 * prevent entering the group when someone is waiting on the group.
 */
internal class BlockableDispatchGroup {
    public init() {
        isBlocked = false
        interalDispatchGroup = DispatchGroup()
        notificationQueue = DispatchQueue.init(label: "GroupNotificationQueue")
    }

    private var notificationQueue: DispatchQueue
    private let interalDispatchGroup: DispatchGroup

    /**
     * Whether or not the group is blocked from receiving new work.
     */
    private var isBlocked: Bool

    /**
     * Enter work into the group. If the group is blocked,
     * this method will subsequently be blocking until the
     * group is unblocked.
     */
    public func enter() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        while self.isBlocked {
            interalDispatchGroup.wait()
        }

        interalDispatchGroup.enter()
    }

    /**
     * Exit work from the group. If the group is
     * emptied, it will notify those waiting.
     */
    public func leave() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        interalDispatchGroup.leave()
    }

    /**
     * Unblock the group. No-op if already unblocked.
     */
    public func unblock() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        isBlocked = false
        interalDispatchGroup.notify(queue: notificationQueue) { }
    }

    /**
     * Block the group and wait for the remaining work to complete.
     */
    public func blockAndWait() {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        isBlocked = true
        interalDispatchGroup.wait()
    }
}
