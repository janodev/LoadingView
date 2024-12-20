import Combine
import Foundation

/// Adds debouncing behavior to the wrapped LoadableObject.
///
/// Debounce delays the execution of the operation until a certain 
/// amount of time has passed without any new events being triggered.
@MainActor
public class DebouncingLoadable<LoadableObject: Loadable>: Loadable, Sendable {
    // MARK: - Loadable
    public typealias Value = LoadableObject.Value
    public var state = PassthroughSubject<LoadingState<Value>, Never>()
    public var isCancelled = false

    // MARK: -
    private var loadable: LoadableObject
    private var cancellables = Set<AnyCancellable>()
    private var debounceIntervalNanoseconds: UInt64
    private var debounceTask: Task<Void, Never>? = nil

    // true when an interval elapses without receiving load calls
    private var isIntervalElapsedWithoutCalls = true

    // true to execute the first call immedately when an interval elapses without receiving load calls
    private var executeFirstImmediately: Bool

    /// Initializes a new instance of the DebouncingLoadable.
    /// - Parameters:
    ///   - wrapping: The underlying loadable object.
    ///   - debounceInterval: The interval to debounce load calls, default is 0.3 seconds.
    ///   - executeFirstImmediately: If true, executes the first load call immediately.
    public init(wrapping: LoadableObject, debounceInterval: TimeInterval = 0.3, executeFirstImmediately: Bool = false) async {
        self.loadable = wrapping
        self.debounceIntervalNanoseconds = UInt64(debounceInterval * 1_000_000_000)
        self.executeFirstImmediately = executeFirstImmediately

        // subscribe to the wrapped loadable and forward calls
        wrapping.state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.state.send(state)
            }
            .store(in: &cancellables)
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
