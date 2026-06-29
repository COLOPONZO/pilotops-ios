
import SwiftUI

@main
struct PilotEntry: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(sessionStore)
                .task {
                    await sessionStore.autoLogin()
                }
        }
    }
}
