import Foundation

final internal class ReadWriteLock {
    private var lock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&lock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&lock)
    }

    func readLock() {
        pthread_rwlock_rdlock(&lock)
    }

    func tryReadLock() {
        pthread_rwlock_tryrdlock(&lock)
    }

    func writeLock() {
        pthread_rwlock_wrlock(&lock)
    }

    func tryWriteLock() {
        pthread_rwlock_trywrlock(&lock)
    }

    func unlock() {
        pthread_rwlock_unlock(&lock)
    }
}
