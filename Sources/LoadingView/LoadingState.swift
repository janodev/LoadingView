import Foundation

/// State of a loading operation.
public enum LoadingState<Value: Sendable>: Sendable, Equatable, CustomStringConvertible {
    /// Initial state indicating no operation is ongoing.
    case idle
    /// A loading operation is in progress.
    case loading
    /// A loading operation finished with error.
    case error(Error)
    /// A loading operation completed successfully.
    case loaded(Value)

    /// This equatable implementation disregards associated values for error and `Value`.
    public static func == (lhs: LoadingState<Value>, rhs: LoadingState<Value>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.error, .error): return true
        case (.loaded, .loaded): return true
        default: return false
        }
    }

    public var description: String {
        switch self {
        case .idle: return ".idle"
        case .loading: return ".loading"
        case .error(let error): return ".error(\(error.localizedDescription))"
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
