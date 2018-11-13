import Foundation

final internal class ReadWriteLock {
    private var lock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&lock)
    }

    @discardableResult
    func readLock() -> Bool {
        return pthread_rwlock_rdlock(&lock) == 0
    }

    @discardableResult
    func tryReadLock() -> Bool {
        return pthread_rwlock_tryrdlock(&lock) == 0
    }

    @discardableResult
    func writeLock() -> Bool {
        return pthread_rwlock_wrlock(&lock) == 0
    }

    @discardableResult
    func tryWriteLock() -> Bool {
        return pthread_rwlock_trywrlock(&lock) == 0
    }

    @discardableResult
    func unlock() -> Bool {
        return pthread_rwlock_unlock(&lock) == 0
    }
}
