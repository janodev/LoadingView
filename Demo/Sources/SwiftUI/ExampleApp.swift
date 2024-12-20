import LoadingView
import SwiftUI

@main
struct ExampleApp: App {
    let userLoader = UserLoader()

    // optionally debounce the response
    // let userLoader = DebouncingLoadable(wrapping: UserLoader(), debounceInterval: 0.5)

    var body: some Scene {
        WindowGroup {
            LoadingView(loader: userLoader) { user in
                Text("User loaded: \(user)")
            }

            // optionally provide non default views for each state

            .emptyView {
                Text("No data available")
            }
            .progressView { progress in
                ProgressView("Loading...")
            }
            .errorView { error in
                Text("An error occurred: \(error.localizedDescription)")
            }
        }
    }
}
