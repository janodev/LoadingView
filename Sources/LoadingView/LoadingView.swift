import OSLog
import SwiftUI
import AsyncAlgorithms

// workaround for compiler crashing with 'isolated deinit' in toolchain 6.1
private final class TaskHolder {
    var task: Task<Void, Never>?
    deinit {
        task?.cancel()
    }
}

@MainActor
@Observable
final class LoadingViewModel<L: Loadable & Sendable>: Sendable {
    private let logger = Logger(subsystem: "loadingview", category: "LoadingViewModel")
    private var loader: L
    var loadingState: LoadingState<L.Value> = .loading(nil)
    private let taskHolder = TaskHolder()

    @MainActor init(loader: L) {
        self.loader = loader
        taskHolder.task = Task { [weak self] in
            for await state in loader.state {
                self?.logger.debug("state: \(state)")
                self?.loadingState = state
                if case .loading(let progress) = state, progress?.isCancelled == true {
                    self?.loader.isCancelled = true
                }
            }
        }
    }

    func load() async {
        await loader.load()
    }
}

/// Renders loading states.
@MainActor
public struct LoadingView<L: Loadable & Sendable, Content: View>: View {
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
