import Foundation

protocol Lock {
    func lock()
    func tryLock()
    func unlock()
}

private class ReadLock: Lock {
    var readLock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&readLock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&readLock)
    }

    func lock() {
        pthread_rwlock_rdlock(&readLock)
    }

    func tryLock() {
        pthread_rwlock_tryrdlock(&readLock)
    }

    func unlock() {
        pthread_rwlock_unlock(&readLock)
    }
}

private class WriteLock: Lock {
    var writeLock = pthread_rwlock_t()

    init() {
        pthread_rwlock_init(&writeLock, nil)
    }

    deinit {
        pthread_rwlock_destroy(&writeLock)
    }

    func lock() {
        pthread_rwlock_wrlock(&writeLock)
    }

    func tryLock() {
        pthread_rwlock_trywrlock(&writeLock)
    }

    func unlock() {
        pthread_rwlock_unlock(&writeLock)
    }
}

class ReadWriteLock {
    let readLock: Lock = ReadLock()
    let writeLock: Lock  = WriteLock()
}
