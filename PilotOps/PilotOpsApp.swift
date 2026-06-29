import SwiftUI

@main
struct PilotOpsApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(sessionStore)
                .task {
                    await NotificationService.shared.requestPermission()
                    await sessionStore.autoLogin()
                }
        }
    }
}
