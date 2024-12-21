@testable import LoadingView
import Combine
import XCTest

private final class MockLoadable: Loadable {
    var state: any AsyncSequence<LoadingState<Int>, Never>
    typealias Value = Int
    var isCancelled = false

    private var continuation: AsyncStream<LoadingState<Int>>.Continuation
    let internalStream: AsyncStream<LoadingState<Int>>

    var loadCallCount = 0

    init() {
        var localContinuation: AsyncStream<LoadingState<Int>>.Continuation!
        let internalStream = AsyncStream<LoadingState<Int>> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
        self.internalStream = internalStream
        self.state = internalStream
    }

    // Updated to async since the Loadable protocol now requires await usage.
    func load() async {
        loadCallCount += 1 // Thread 1: Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value
        _ = continuation.yield(.loading(nil))
        _ = continuation.yield(.loaded(loadCallCount))
    }
}

final class DebouncingLoadableTests: XCTestCase {
    private var mockLoadable: MockLoadable!

    override func setUp() async throws {
        try await super.setUp()
        mockLoadable = await MockLoadable()
    }

    @MainActor
    func testDebounceEffect() async {
        // GIVEN a debouncer with immediate execution
        let debouncer = await DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: true)

        // WHEN there are quick consecutive calls
        await debouncer.load()
        await debouncer.load()
        await debouncer.load()

        // wait a bit for async execution
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // THEN only one load should actually execute
        XCTAssertEqual(mockLoadable.loadCallCount, 1, "Only one load() should be executed due to debouncing.")
    }

    @MainActor
    func testImmediateExecutionTrue() async {
        // GIVEN a debouncer with immediate execution
        let debouncer = await DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: true)

        // WHEN an execution occurs
        await debouncer.load()
        try? await Task.sleep(nanoseconds: 400_000_000)  // wait beyond the debounce interval

        // THEN the next load executes immediately
        await debouncer.load()

        // wait for async execution
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        XCTAssertEqual(mockLoadable.loadCallCount, 2, "Load should be executed immediately after waiting out the interval.")
    }

    @MainActor
    func testImmediateExecutionFalse() async {
        // GIVEN a debouncer without immediate execution
        let debouncer = await DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: false)

        // WHEN we call load once and wait less than debounce interval
        await debouncer.load()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // THEN load hasn't executed yet
        XCTAssertEqual(mockLoadable.loadCallCount, 0, "Load should be pending execution due to debouncing.")
    }
}
