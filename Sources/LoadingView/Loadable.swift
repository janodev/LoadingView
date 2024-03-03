import Combine
import Foundation
/**
 An object that loads a value and publish its loading state

 Example:
 ```
 class UserLoader: Loadable {
     typealias Value = User
     var state = PassthroughSubject<LoadingState<User>, Never>()

     func load() async {
         state.send(.loading)
         do {
             let user = try await fetchUser()
             state.send(.loaded(user))
         } catch {
             state.send(.error(user))
         }
     }
     // ...
 }
 ```
 */
public protocol Loadable {
    /// Loaded value.
    associatedtype Value: Sendable

    /// Publisher for the loading state of the `Value`.
    var state: PassthroughSubject<LoadingState<Value>, Never> { get }

    /// Initiates the loading of `Value`.
    ///
    /// Typically you will send a `.loading` state through the `state`
    /// publisher, then attempt to load the `Value` and publish either
    /// a `.loaded(value)` or an `.error(error)`.
    func load() async
}
