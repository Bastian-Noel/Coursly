import SwiftUI

@main
struct CourslyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)

            Text("Coursly")
                .font(.largeTitle.bold())

            Text("Hello World 👋")
                .font(.title2)

            Text("La distribution iOS fonctionne.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
