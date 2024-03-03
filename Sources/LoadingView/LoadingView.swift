import Combine
import SwiftUI

final class LoadingViewModel<L: Loadable>: ObservableObject {
    private var loader: DebouncingLoadable<L>
    private var cancellables = Set<AnyCancellable>()
    @Published var loadingState: LoadingState<L.Value> = .idle

    init(loader: L) {
        self.loader = DebouncingLoadable(wrapping: loader)

        // subscribe to loader’s state updates
        loader.state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.loadingState = state
            }
            .store(in: &cancellables)
    }

    func load() async {
        await loader.load()
    }
}

// LoadingView displaying the loading state
public struct LoadingView<L: Loadable, Content: View>: View {
    @StateObject private var viewModel: LoadingViewModel<L>
    private var content: (L.Value) -> Content

    public init(loader: L, @ViewBuilder content: @escaping (L.Value) -> Content) {
        self._viewModel = StateObject(wrappedValue: LoadingViewModel(loader: loader))
        self.content = content
    }

    /// MARK: - Accessory views

    private var _emptyView: () -> any View = {
        EmptyView()
    }

    private var _progressView: () -> any View = {
        ProgressView()
    }

    private var _errorView: (Error) -> any View = { error in
        Text("Error: \(error.localizedDescription)")
    }

    public func emptyView(@ViewBuilder _ view: @escaping () -> any View) -> Self {
        var copy: Self = self
        copy._emptyView = view
        return copy
    }

    public func progressView(@ViewBuilder _ view: @escaping () -> any View) -> Self {
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
        case .loading:
            AnyView(_progressView())
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
