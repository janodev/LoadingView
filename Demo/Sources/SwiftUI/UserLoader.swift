import Foundation
import LoadingView
import SwiftUI

struct User: Sendable {}

@MainActor
final class UserLoader: Loadable, Sendable {
    typealias Value = User

    var isCancelled: Bool = false

    private var continuation: AsyncStream<LoadingState<User>>.Continuation!
    lazy var state: AsyncStream<LoadingState<User>> = {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in
                // handle termination (not really needed in this example)
            }
        }
    }()

    func load() {
        continuation.yield(.loading(Progress()))

        Task { @MainActor in
            do {
                let userData = try await fetchUser()
                _ = continuation.yield(.loaded(userData))
            } catch {
                _ = continuation.yield(.error(error))
            }
        }
    }

    private func fetchUser() async throws -> User {
        // Simulate a network call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return User()
    }
}
