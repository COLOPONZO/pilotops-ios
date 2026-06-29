import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    private let deviceTokenKey = "apnsDeviceToken"
    private let pilotNameKey = "storedPilotName"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Permiso push remoto:", granted)

            if let error {
                print("❌ Error permiso push:", error.localizedDescription)
            }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        print("📱 DEVICE TOKEN APNS:")
        print(token)

        UserDefaults.standard.set(token, forKey: deviceTokenKey)

        if let practico = UserDefaults.standard.string(forKey: pilotNameKey),
           !practico.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            Task {
                await PushRegistrationService.shared.registerDevice(
                    practico: practico,
                    deviceToken: token
                )
            }
        } else {
            print("ℹ️ Token APNs guardado. Falta práctico para registrar en Oracle.")
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Error registrando APNS:", error.localizedDescription)
    }
}
