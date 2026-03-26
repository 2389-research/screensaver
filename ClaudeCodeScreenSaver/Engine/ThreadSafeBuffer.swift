// ABOUTME: Thread-safe FIFO ring buffer for cross-thread event delivery.
// ABOUTME: Used to pass parsed JSONL events from background queue to animation thread.

import Foundation

final class ThreadSafeBuffer<Element> {
    private var storage: [Element] = []
    private let capacity: Int
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    func enqueue(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        if storage.count >= capacity {
            storage.removeFirst()
        }
        storage.append(element)
    }

    func dequeue() -> Element? {
        lock.lock()
        defer { lock.unlock() }
        guard !storage.isEmpty else { return nil }
        return storage.removeFirst()
    }
}
