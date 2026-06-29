import SwiftUI

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.isLoggedIn {
                MainTabView()
            } else if sessionStore.isAttemptingAutoLogin {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Conectando...")
                        .foregroundStyle(.secondary)
                }
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
    }
}
