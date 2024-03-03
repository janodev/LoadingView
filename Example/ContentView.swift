import LoadingView
import SwiftUI

struct ContentView: View {
    private let loadable = MyStringLoadable()

    var body: some View {
        LoadingView(loader: loadable) { value in
            Text(value)
        }
        .task {
            await loadable.load()
        }
    }
}

#Preview {
    ContentView()
}
