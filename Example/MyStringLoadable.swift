import Combine
import Foundation
import LoadingView
import OSLog

final class MyStringLoadable: Loadable {
    typealias Value = String
    var state = PassthroughSubject<LoadingState<Value>, Never>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "bundle", category: "MyStringLoadable")
    private var cancellables = Set<AnyCancellable>()

    init() {
        state
            .sink { [weak self] loadingState in
                self?.logger.debug("\(loadingState)")
            }
            .store(in: &cancellables)
    }

    func load() async {
        state.send(.loading)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        state.send(.loaded("Loaded Data"))
    }
}
