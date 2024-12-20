# ``LoadingView``

Manages screen states such as idle, loading, loaded, and error.

## Overview

LoadingView provides a consistent way of dealing with screen states. Use it like this:

```swift
// loader object for the screen data
let userLoader = UserLoader() 

var body: some View {
    // pass the loader and a success view
    LoadingView(loader: userLoader) { user in
        Text("User loaded: \(user)") 
    }
}
```
Default views are provided for the idle, loading, and error states, but custom views are allowed:
```swift
LoadingView(loader: userLoader) { user in
    Text("User loaded: \(user)")
}
.emptyView {
    Text("No data available")
}
.progressView {
    ProgressView("Loading...")
}
.errorView { error in
    Text("An error occurred: \(error.localizedDescription)")
}
```

## The Loader Object 

The loader object must conform to ``Loadable`` and return a ``LoadingState``.

![Loadable](LoadingState-Loadable)

Here is a sample implementation:

```swift
import Combine
import LoadingView

class UserLoader: Loadable {
    typealias Value = User

    var state = PassthroughSubject<LoadingState<User>, Never>()

    func load() async {
        state.send(.loading)
        do {
            let userData = try await fetchUser()
            state.send(.loaded(userData))
        } catch {
            state.send(.error(error))
        }
    }

    // simulate an API call
    private func fetchUser() async throws -> User {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return User()
    }
}
```

## Class diagram

![LoadingView](LoadingView)

Sequence
1. Your screen passes a loader and a success view to LoadingView.
2. When LoadingView appears, it calls load() on the loader object.
3. The loader object sends a .loading state and starts fetching data.
4. The loader object sends an error or success state.
5. The LoadingView refreshes with each state, showing the appropriate view.

There is a complete example in the Example folder.

## Debouncing 

Optionally you could wrap the loader with a ``DebouncingLoadable``. 
Admittedly doesn’t make much sense in this example, but it illustrates how behavior can be composed.

```swift
let userLoader = DebouncingLoadable(
    wrapping: UserLoader(), 
    debounceInterval: 0.5
)
```

## Final note

This implementation wouldn’t change much replacing the PassthroughSubject with a closure. Closures are simple, faster, but less powerful handling streams. Combine is integrated with SwiftUI, has many operators, and sofisticated functionality like back pressure management, and multiple listeners. While Combine is overkill for the example here, this is not about simple examples but about providing functionality for a whole app so I opted for the most powerful option. 

## Topics

### Badabung

- ``DebouncingLoadable``
- ``Loadable``
- ``LoadingState``
- ``LoadingView``
