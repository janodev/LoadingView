import Combine
import LoadingView

struct User {}

@MainActor
final class UserLoader: Loadable, Sendable {
    var isCancelled: Bool {
        get { false }
        set {}
    }

    typealias Value = User

    let state = PassthroughSubject<LoadingState<User>, Never>()

    func load() {
        state.send(.loading(Progress()))
        Task {
            do {
                let userData = try await fetchUser()
                await MainActor.run {
                    state.send(.loaded(userData))
                }
            } catch {
                await MainActor.run {
                    state.send(.error(error))
                }
            }
        }
    }

    private func fetchUser() async throws -> User {
        // simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return User()
    }
}
