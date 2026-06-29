import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Permiso de notificaciones: \(granted)")
        } catch {
            print("❌ Error pidiendo permiso de notificaciones: \(error.localizedDescription)")
        }
    }

    func sendStatusChangeNotification(from previous: String, to current: String) {
        let content = UNMutableNotificationContent()
        content.title = "Cambio de estado"
        content.body = "\(previous) → \(current)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Error enviando notificación de estado: \(error.localizedDescription)")
            } else {
                print("🔔 Notificación enviada: \(previous) → \(current)")
            }
        }
    }

    func sendFirstPositionNotification(practicoName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Posición 1 en espera"
        content.body = "\(practicoName) quedó primero en la pizarra de espera."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Error enviando notificación de posición 1: \(error.localizedDescription)")
            } else {
                print("🔔 Notificación enviada: posición 1 para \(practicoName)")
            }
        }
    }

    func sendAssignedToProcessNotification(practicoName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Trabajo asignado"
        content.body = "\(practicoName) pasó de En espera a T. Proceso."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Error enviando notificación de asignación: \(error.localizedDescription)")
            } else {
                print("🔔 Notificación enviada: En espera → T. Proceso para \(practicoName)")
            }
        }
    }
}
