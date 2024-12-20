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
