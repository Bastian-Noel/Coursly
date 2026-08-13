import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
            Text("Coursly")
                .font(.largeTitle.bold())
            Text("Hello World 👋")
                .font(.title2)
            Text("Build de test prête.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
