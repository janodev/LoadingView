import Foundation

final class RetryableLoader<Base: Loadable & Sendable>: Loadable, Sendable {
    var isCancelled = false
    typealias Value = Base.Value

    private let base: Base
    private let maxAttempts: Int
    private let internalStream: AsyncStream<LoadingState<Value>>
    private var continuation: AsyncStream<LoadingState<Value>>.Continuation?

    var state: any AsyncSequence<LoadingState<Value>, Never>

    init(base: Base, maxAttempts: Int) {
        self.base = base
        self.maxAttempts = maxAttempts

        var localContinuation: AsyncStream<LoadingState<Value>>.Continuation!
        let stream = AsyncStream<LoadingState<Value>> { continuation in
            localContinuation = continuation
        }
        self.internalStream = stream
        self.continuation = localContinuation
        self.state = stream

        self.continuation?.onTermination = { @Sendable _ in
            Task { @MainActor [weak self] in
                self?.isCancelled = true
            }
        }
    }

    func load() async {
        guard let continuation = continuation else { return }

        var attempt = 0
        repeat {
            do {
                continuation.yield(.loading(Progress(
                    message: attempt > 0 ? "Retrying…" : nil
                )))

                await base.load()

                // process resulting states from base.load()
                for await state in base.state {
                    switch state {
                    case .loaded(let value):
                        continuation.yield(.loaded(value))
                        continuation.finish()
                        return
                    case .failure(let error):
                        throw error
                    case .loading:
                        break
                    case .idle:
                        break
                    }
                }

            } catch {
                guard !isCancelled else { return }

                attempt += 1
                if attempt >= maxAttempts {
                    continuation.yield(.failure(error))
                    continuation.finish()
                    return
                }

                try? await Task.sleep(
                    nanoseconds: UInt64(pow(2, Double(attempt))) * 1_000_000_000
                )
            }
        } while !isCancelled

        // finish after cancelled
        continuation.finish()
    }
}
