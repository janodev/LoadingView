import Combine
import Foundation

public class DebouncingLoadable<LoadableObject: Loadable>: Loadable {
    public typealias Value = LoadableObject.Value
    public var state = PassthroughSubject<LoadingState<Value>, Never>()
    
    private var loadable: LoadableObject
    private var cancellables = Set<AnyCancellable>()
    private var debounceInterval: TimeInterval

    private var debounceTask: Task<Void, Never>? = nil

    public init(wrapping: LoadableObject, debounceInterval: TimeInterval = 0.3) {
        self.loadable = wrapping
        self.debounceInterval = debounceInterval

        wrapping.state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.state.send(state)
            }
            .store(in: &cancellables)
    }

    public func load() async {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await loadable.load()
        }
    }
}
