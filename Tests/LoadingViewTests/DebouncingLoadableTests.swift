@testable import LoadingView
import Combine
import XCTest

private final class MockLoadable: Loadable {
    typealias Value = Int
    var state = PassthroughSubject<LoadingState<Int>, Never>()
    var loadCallCount = 0

    func load() async {
        print("incrementing count")
        loadCallCount += 1
        state.send(.loading)
        state.send(.loaded(loadCallCount))
    }
}

final class DebouncingLoadableTests: XCTestCase {
    private var mockLoadable: MockLoadable!

    override func setUp() {
        super.setUp()
        mockLoadable = MockLoadable()
    }

    func testDebounceEffect() async {
        // GIVEN a debouncer with immediate execution
        let debouncer = DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: true)

        // WHEN there are quick consecutive calls
        await debouncer.load()
        await debouncer.load()
        await debouncer.load()

        // call won’t wait for debounce delay but needs a minimum delay to execute asynchronously
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // THEN all calls are debounced minus one
        XCTAssertEqual(mockLoadable.loadCallCount, 1, "Only one load() should be executed due to debouncing.")
    }

    func testImmediateExecutionTrue() async {
        // GIVEN a debouncer with immediate execution
        let debouncer = DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: true)

        // WHEN there is an execution and we wait for more than the debounce interval
        await debouncer.load()
        try? await Task.sleep(nanoseconds: 400_000_000)  // 0.4 seconds

        // THEN the next load() executes immediately
        await debouncer.load()
        
        // call won’t wait for debounce delay but needs a minimum delay to execute asynchronously
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        XCTAssertEqual(mockLoadable.loadCallCount, 2, "Load should be executed immediately after the interval without calls.")
    }

    func testImmediateExecutionFalse() async {
        // GIVEN a debouncer without immediate execution
        let debouncer = DebouncingLoadable(wrapping: mockLoadable, debounceInterval: 0.3, executeFirstImmediately: false)

        // WHEN there is an execution and we wait for less than the debounce interval
        await debouncer.load()
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // THEN load() is still pending execution
        XCTAssertEqual(mockLoadable.loadCallCount, 0, "Load should be pending execution.")
    }
}
