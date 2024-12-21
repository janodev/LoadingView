import AsyncAlgorithms
import LoadingView
import SwiftUI

struct User: Sendable {}

@MainActor
final class UserLoader: Loadable, Sendable {
    // MARK: - Loadable
    typealias Value = User
    public var isCancelled: Bool = false
    public var state: any AsyncSequence<LoadingState<User>, Never>

    // `state` implementation
    private let internalStream: AsyncStream<LoadingState<User>>

    // continuation of the internalStream, where we’ll be yielding states
    private var continuation: AsyncStream<LoadingState<User>>.Continuation?

    public init() {
        var localContinuation: AsyncStream<LoadingState<User>>.Continuation!
        let stream = AsyncStream<LoadingState<User>> { continuation in
            localContinuation = continuation
        }
        self.internalStream = stream
        self.continuation = localContinuation
        self.state = stream
            // Add here any transformation from AsyncAlgorithms, e.g.
            // .debounce(for: .seconds(0.5))

        self.continuation?.onTermination = { @Sendable _ /* termination */ in
            Task { @MainActor [weak self] in
                self?.isCancelled = true
            }
        }
    }

    /// Initiates the loading operation, publishing relevant states along the way.
    public func load() async {
        guard let continuation = continuation, !isCancelled else {
            return
        }

        // Loading at 0% progress.
        // Passing progress info is optional, you may also pass .loading(nil)
        continuation.yield(.loading(Progress()))

        do {
            let user = try await fetchUser()
            guard !isCancelled else {
                return // client cancelled, result no longer needed
            }
            continuation.yield(.loaded(user))
        } catch {
            guard !isCancelled else {
                return // client cancelled, skip sending an error
            }
            continuation.yield(.error(error))
        }
    }

    /// Example of an async fetch operation (simulating a network request).
    private func fetchUser() async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        return User()
    }
}
