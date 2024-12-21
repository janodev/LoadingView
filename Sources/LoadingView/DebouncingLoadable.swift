import Combine
import Foundation

/// Adds debouncing behavior to the wrapped LoadableObject.
///
/// Debounce delays the execution of the operation until a certain 
/// amount of time has passed without any new events being triggered.
@MainActor
public class DebouncingLoadable<LoadableObject: Loadable>: Loadable, Sendable {
    public typealias Value = LoadableObject.Value

    // AsyncStream replacing PassthroughSubject
    public let state: AsyncStream<LoadingState<Value>>
    private let continuation: AsyncStream<LoadingState<Value>>.Continuation

    public var isCancelled = false

    private var loadable: LoadableObject
    private var debounceIntervalNanoseconds: UInt64
    private var debounceTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var isIntervalElapsedWithoutCalls = true
    private var executeFirstImmediately: Bool

    /// Initializes a new instance of the DebouncingLoadable.
    /// - Parameters:
    ///   - wrapping: The underlying loadable object.
    ///   - debounceInterval: The interval to debounce load calls, default is 0.3 seconds.
    ///   - executeFirstImmediately: If true, executes the first load call immediately.
    public init(wrapping: LoadableObject,
                debounceInterval: TimeInterval = 0.3,
                executeFirstImmediately: Bool = false) async {
        self.loadable = wrapping
        self.debounceIntervalNanoseconds = UInt64(debounceInterval * 1_000_000_000)
        self.executeFirstImmediately = executeFirstImmediately

        var continuation: AsyncStream<LoadingState<Value>>.Continuation!
        self.state = AsyncStream { cont in
            continuation = cont
            cont.onTermination = { @Sendable _ in

            }
        }
        self.continuation = continuation

        // Start listening to wrapped loadable's state
        stateTask = Task { [weak self] in
            for await state in wrapping.state {
                self?.continuation.yield(state)
            }
        }
    }

    deinit {
        stateTask?.cancel()
        debounceTask?.cancel()
        continuation.finish()
    }

    /// Initiates the loading process, applying debouncing rules based on initialization parameters.
    public func load() {
        if executeFirstImmediately && isIntervalElapsedWithoutCalls {
            isIntervalElapsedWithoutCalls = false
            Task {
                await executeLoad()
            }
        } else {
            debounceLoad()
        }
    }

    /// Executes the load operation on the underlying LoadableObject.
    private func executeLoad() async {
        loadable.load()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceIntervalNanoseconds)
            isIntervalElapsedWithoutCalls = true
        }
    }

    /// Debounces the load operation, ensuring only one operation is triggered after quick consecutive calls.
    private func debounceLoad() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceIntervalNanoseconds)
            guard !Task.isCancelled else { return }
            isIntervalElapsedWithoutCalls = false
            Task {
                await executeLoad()
            }
        }
    }
}
