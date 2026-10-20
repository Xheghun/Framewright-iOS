import Foundation

// Tokens may be released off the main actor when their owner is deallocated.
final class ObservationLifetime: @unchecked Sendable {
    private let lock = NSLock()
    private var observations: [NSKeyValueObservation] = []
    private var notifications: [any NSObjectProtocol] = []

    func add(_ observation: NSKeyValueObservation) { lock.withLock { observations.append(observation) } }
    func addNotification(_ token: any NSObjectProtocol) { lock.withLock { notifications.append(token) } }

    func cancel() {
        let tokens = lock.withLock {
            let result = (observations, notifications)
            observations.removeAll()
            notifications.removeAll()
            return result
        }
        for observation in tokens.0 { observation.invalidate() }
        for notification in tokens.1 { NotificationCenter.default.removeObserver(notification) }
    }

    deinit { cancel() }
}

func deliverOnMain(_ operation: @escaping @MainActor @Sendable () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated { operation() }
    } else {
        DispatchQueue.main.async { operation() }
    }
}
