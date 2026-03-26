// ABOUTME: Tests for the thread-safe ring buffer used for cross-thread event delivery.
// ABOUTME: Verifies FIFO ordering, capacity limits, and concurrent access safety.

import XCTest

final class ThreadSafeBufferTests: XCTestCase {

    func testEnqueueAndDequeue() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        buffer.enqueue(42)
        XCTAssertEqual(buffer.dequeue(), 42)
    }

    func testDequeueFromEmptyReturnsNil() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        XCTAssertNil(buffer.dequeue())
    }

    func testFIFOOrder() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 10)
        for i in 1...3 { buffer.enqueue(i) }
        XCTAssertEqual(buffer.dequeue(), 1)
        XCTAssertEqual(buffer.dequeue(), 2)
        XCTAssertEqual(buffer.dequeue(), 3)
    }

    func testCapacityDropsOldest() {
        let buffer = ThreadSafeBuffer<Int>(capacity: 3)
        for i in 1...4 { buffer.enqueue(i) }
        XCTAssertEqual(buffer.dequeue(), 2)
    }

    func testConcurrentAccess() async {
        let buffer = ThreadSafeBuffer<Int>(capacity: 1000)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for i in 0..<500 { buffer.enqueue(i) } }
            group.addTask { for i in 500..<1000 { buffer.enqueue(i) } }
        }
        var count = 0
        while buffer.dequeue() != nil { count += 1 }
        XCTAssertEqual(count, 1000)
    }
}
