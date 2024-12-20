import Combine
import Foundation
/**
 An object that loads a value and publish its loading state.

 See `UserLoader` in the Demo folder for a sample implementation.
 */
@MainActor
public protocol Loadable {
    /// Loaded value.
    associatedtype Value: Sendable

    /// Publisher for the loading state of the `Value`.
    var state: PassthroughSubject<LoadingState<Value>, Never> { get }

    /// Flag that allows the user to cancel the loading operation.
    var isCancelled: Bool { get set }

    /// Initiates the loading of `Value`.
    ///
    /// Typically you will send a `.loading` state through the `state`
    /// publisher, then attempt to load the `Value` and publish either
    /// a `.loaded(value)` or an `.error(error)`.
    func load()
}
