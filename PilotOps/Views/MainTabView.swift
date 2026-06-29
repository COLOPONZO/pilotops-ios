import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CambioEstadoView()
            }
            .tabItem {
                Label("Estado", systemImage: "person.3.fill")
            }

            NavigationStack {
                TrabajosView()
            }
            .tabItem {
                Label("Trabajos", systemImage: "ship.fill")
            }
        }
    }
}
