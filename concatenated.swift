import Foundation

public struct Progress: Sendable, Equatable {
    public let isCancelled: Bool?
    public let message: String?
    public let percent: Int? // 0 to 100
    public init(isCancelled: Bool? = nil, message: String? = nil, percent: Int? = nil) {
        self.isCancelled = isCancelled
        self.message = message
        self.percent = percent
    }
}

/// State of a loading operation.
public enum LoadingState<Value: Sendable>: Sendable, Equatable, CustomStringConvertible {
    /// Initial state indicating no operation is ongoing.
    case idle
    /// A loading operation is in progress.
    case loading(Progress?)
    /// A loading operation finished with error.
    case error(Error)
    /// A loading operation completed successfully.
    case loaded(Value)

    /// This equatable implementation disregards associated values for error and `Value`.
    public static func == (lhs: LoadingState<Value>, rhs: LoadingState<Value>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading(let progress1), .loading(let progress2)): return progress1 == progress2
        case (.error, .error): return true
        case (.loaded, .loaded): return true
        default: return false
        }
    }

    public var description: String {
        switch self {
        case .idle: return ".idle"
        case .loading(let progress): return ".loading percent: \(progress?.percent?.description ?? ""), message: \(progress?.message ?? "")"
        case .error(let error):
            return error.localizedDescription
        case .loaded(let value):
            var string = ""
            if let desc = (value as? CustomStringConvertible)?.description {
                string = desc
            } else {
                dump(value, to: &string)
            }
            return ".loaded(\(string))"
        }
    }
}
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
import Combine
import Foundation
/**
 An object that loads a value and publish its loading state.

 See `UserLoader` in the Demo folder for a sample implementation.
 */
@MainActor
public protocol Loadable {
    /// Loaded value.
    associatedtype Value: Sendable

    /// Publisher for the loading state of the `Value`.
    var state: PassthroughSubject<LoadingState<Value>, Never> { get }

    /// Flag that allows the user to cancel the loading operation.
    var isCancelled: Bool { get set }

    /// Initiates the loading of `Value`.
    ///
    /// Typically you will send a `.loading` state through the `state`
    /// publisher, then attempt to load the `Value` and publish either
    /// a `.loaded(value)` or an `.error(error)`.
    func load()
}
import Combine
import OSLog
import SwiftUI

@MainActor
@Observable
final class LoadingViewModel<L: Loadable & Sendable>: Sendable {
    private let logger = Logger(subsystem: "loadingview", category: "LoadingViewModel")
    private var loader: L
    private var cancellables = Set<AnyCancellable>()
    var loadingState: LoadingState<L.Value> = .loading(nil)

    @MainActor init(loader: L) {
        self.loader = loader

        // subscribe to loader’s state updates
        loader.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.logger.debug("state: \(state)")
                self?.loadingState = state
                if case .loading(let progress) = state, progress?.isCancelled == true {
                    self?.loader.isCancelled = true
                }
            }
            .store(in: &cancellables)
    }

    func load() async {
        loader.load()
    }
}

/// Renders loading states.
@MainActor
public struct LoadingView<L: Loadable, Content: View>: View {
    @State private var viewModel: LoadingViewModel<L>
    private var content: (L.Value) -> Content

    public init(loader: L, @ViewBuilder content: @escaping (L.Value) -> Content) {
        self._viewModel = State(wrappedValue: LoadingViewModel(loader: loader))
        self.content = content
    }

    /// MARK: - Accessory views

    private var _emptyView: () -> any View = {
        EmptyView()
    }

    private var _progressView: (Progress?) -> any View = { progress in
        VStack {
            ProgressView()
            VStack {
                if let percent = progress?.percent {
                    Text("\(percent)%")
                }
                if let message = progress?.message {
                    Text(message)
                }
                if let isCancelled = progress?.isCancelled, isCancelled {
                    Text("Loading cancelled.")
                }
            }
        }
    }

    private var _errorView: (Error) -> any View = { error in
        Text(".Error: \(error.localizedDescription)")
            .accessibilityLabel(".An error occurred")
            .accessibilityValue(error.localizedDescription)
    }

    public func emptyView(@ViewBuilder _ view: @escaping () -> any View) -> Self {
        var copy: Self = self
        copy._emptyView = view
        return copy
    }

    public func progressView(@ViewBuilder _ view: @escaping (Progress?) -> any View) -> Self {
        var copy: Self = self
        copy._progressView = view
        return copy
    }

    public func errorView(@ViewBuilder _ view: @escaping (Error) -> any View) -> Self {
        var copy: Self = self
        copy._errorView = view
        return copy
    }

    /// MARK: - View

    public var body: some View {
        switch viewModel.loadingState {
        case .idle:
            AnyView(_emptyView())
        case .loading(let progress):
            AnyView(_progressView(progress))
                .task {
                    await viewModel.load()
                }
        case .loaded(let value):
            content(value)
        case .error(let error):
            AnyView(_errorView(error))
        }
    }
}
