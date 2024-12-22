@testable import LoadingView
import XCTest
import AsyncAlgorithms

enum MockError: Error, Equatable {
    case somethingWentWrong
}

// MARK: - MockLoadable: Fails once, then succeeds

/// A simple mock that yields `.failure` on the first `load()`,
/// and `.loaded` on the second and subsequent loads.
@MainActor
final class MockLoadableFailOnce: Loadable, Sendable {
    typealias Value = Int

    var isCancelled = false
    private let internalStream: AsyncStream<LoadingState<Int>>
    private var continuation: AsyncStream<LoadingState<Int>>.Continuation?

    /// Exposes the read-only side of the stream for `Loadable`.
    var state: any AsyncSequence<LoadingState<Int>, Never>

    private var loadCallCount = 0

    init() {
        var localContinuation: AsyncStream<LoadingState<Int>>.Continuation!
        let stream = AsyncStream<LoadingState<Int>> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
        self.internalStream = stream
        self.state = stream

        // When the consumer cancels the stream, mark isCancelled
        self.continuation?.onTermination = { @Sendable _ in
            Task { @MainActor [weak self] in
                self?.isCancelled = true
            }
        }
    }

    func load() async {
        guard let continuation = continuation, !isCancelled else { return }

        loadCallCount += 1
        continuation.yield(.loading(nil))  // Just a .loading state

        // Fail the first time, succeed on second and thereafter
        if loadCallCount == 1 {
            continuation.yield(.failure(MockError.somethingWentWrong))
        } else {
            continuation.yield(.loaded(loadCallCount))
        }
    }
}

// MARK: - MockLoadableAlwaysFail

/// A simple mock that always fails, no matter how many times `load()` is called.
@MainActor
final class MockLoadableAlwaysFail: Loadable, Sendable {
    typealias Value = Int

    var isCancelled = false
    private let internalStream: AsyncStream<LoadingState<Int>>
    private var continuation: AsyncStream<LoadingState<Int>>.Continuation?

    var state: any AsyncSequence<LoadingState<Int>, Never>

    init() {
        var localContinuation: AsyncStream<LoadingState<Int>>.Continuation!
        let stream = AsyncStream<LoadingState<Int>> { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
        self.internalStream = stream
        self.state = stream

        self.continuation?.onTermination = { @Sendable _ in
            Task { @MainActor [weak self] in
                self?.isCancelled = true
            }
        }
    }

    func load() async {
        guard let continuation = continuation, !isCancelled else { return }
        continuation.yield(.loading(nil))
        continuation.yield(.failure(MockError.somethingWentWrong))
    }
}


// MARK: - Test suite for RetryableLoader

@MainActor
final class RetryableLoaderTests: XCTestCase {
    /// Gathers AsyncSequence states into an array.
    /// Limit to 10 so it doesn’t hang with infintei sequences
    private func collectStates<S: AsyncSequence>(
        _ sequence: S,
        limit: Int = 10
    ) async throws -> [S.Element] {
        var result = [S.Element]()
        for try await element in sequence.prefix(limit) {
            result.append(element)
        }
        return result
    }

    func testRetryAfterOneFailure_succeedsOnSecondTry() async throws {
        // GIVEN a mock that fails once, then succeeds
        let base = MockLoadableFailOnce()

        // mAke 2 attempts
        let loader = RetryableLoader(base: base, maxAttempts: 2)

        // collect states in the background
        let statesTask = Task {
            try await collectStates(loader.state)
        }

        // WHEN invoking load()
        await loader.load()

        // THEN states should be: .loading, .failure, .loading, .loaded
        let states = try await statesTask.value

        // from the arrya I’m just checking for a .loaded(2) because we fail and then we succeed
        guard states.contains(where: {
            if case .loaded(let value) = $0, value == 2 {
                return true
            }
            return false
        }) else {
            XCTFail("Expected to eventually see .loaded(2)")
            return
        }
    }

    func testExceedMaxAttempts_fails() async throws {
        // GIVEN a mock that always fails
        let base = MockLoadableAlwaysFail()

        // make 2 attempts
        let loader = RetryableLoader(base: base, maxAttempts: 2)

        // Start collecting states
        let statesTask = Task {
            try await collectStates(loader.state)
        }

        // WHEN invoking load()
        await loader.load()

        // THEN it fails after 2 attempts
        let states = try await statesTask.value

        guard states.contains(where: {
            if case .failure(let error) = $0 {
                return (error as? MockError) == .somethingWentWrong
            }
            return false
        }) else {
            XCTFail("Expected a .failure(somethingWentWrong)")
            return
        }
    }
}
