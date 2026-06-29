import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {

    @Published var currentSession: UserSession?
    @Published var highlightedPilotName: String = ""
    @Published var isAttemptingAutoLogin: Bool = false

    private let loginService = LoginService()

    private let keychainService = "PilotOpsCredentials"
    private let usernameAccount = "username"
    private let passwordAccount = "password"

    private let pilotNameKey = "storedPilotName"
    private let deviceTokenKey = "apnsDeviceToken"

    var isLoggedIn: Bool {
        currentSession != nil
    }

    init() {
        if let savedPilotName = UserDefaults.standard.string(forKey: pilotNameKey),
           !savedPilotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            highlightedPilotName = savedPilotName
        }
    }

    func autoLogin() async {
        if currentSession != nil { return }

        guard let username = KeychainHelper.shared.read(service: keychainService, account: usernameAccount),
              let password = KeychainHelper.shared.read(service: keychainService, account: passwordAccount),
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("ℹ️ No hay credenciales guardadas para auto-login")
            return
        }

        guard !highlightedPilotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("ℹ️ No hay práctico guardado para auto-login")
            clearSavedCredentials()
            return
        }

        isAttemptingAutoLogin = true
        defer { isAttemptingAutoLogin = false }

        print("🔐 Intentando auto-login...")

        do {
            let session = try await loginService.login(username: username, password: password)
            print("✅ Auto-login exitoso")
            saveSession(session)
            await registerPushIfPossible()
        } catch {
            print("❌ Auto-login falló: \(error.localizedDescription)")
            clearSavedCredentials()
        }
    }

    func saveSession(_ session: UserSession) {
        currentSession = session
    }

    func saveCredentials(username: String, password: String) {
        KeychainHelper.shared.save(username, service: keychainService, account: usernameAccount)
        KeychainHelper.shared.save(password, service: keychainService, account: passwordAccount)
    }

    func savePilotName(_ pilotName: String) {
        let cleanPilotName = pilotName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        highlightedPilotName = cleanPilotName
        UserDefaults.standard.set(cleanPilotName, forKey: pilotNameKey)

        Task {
            await registerPushIfPossible()
        }
    }

    func registerPushIfPossible() async {
        let cleanPilotName = highlightedPilotName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !cleanPilotName.isEmpty else {
            print("ℹ️ No se registra push: práctico vacío")
            return
        }

        guard let token = UserDefaults.standard.string(forKey: deviceTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("ℹ️ No se registra push: todavía no hay token APNs")
            return
        }

        await PushRegistrationService.shared.registerDevice(
            practico: cleanPilotName,
            deviceToken: token
        )
    }

    func logout() {
        currentSession = nil

        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }

    func clearSavedCredentials() {
        KeychainHelper.shared.delete(service: keychainService, account: usernameAccount)
        KeychainHelper.shared.delete(service: keychainService, account: passwordAccount)
    }

    func resetUserIdentity() {
        currentSession = nil
        highlightedPilotName = ""

        clearSavedCredentials()

        UserDefaults.standard.removeObject(forKey: pilotNameKey)

        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }

        print("🧹 Identidad local borrada. Se requerirá nuevo login.")
    }
}
