import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {

    @Published var username: String = ""
    @Published var password: String = ""

    @Published var practicosParana: [PracticoEmpresa] = []
    @Published var selectedPilotName: String = ""

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let loginService = LoginService()
    private let practicosIndexService = PracticosIndexService()

    private var pendingSession: UserSession?

    func loginAndLoadPracticos(sessionStore: SessionStore) async {
        errorMessage = nil
        isLoading = true

        defer { isLoading = false }

        let cleanUsername = normalizeCredential(username)
        let cleanPassword = normalizeCredential(password)

        do {
            let session = try await loginService.login(
                username: cleanUsername,
                password: cleanPassword
            )

            print("✅ Login exitoso para: \(session.username)")
            print("🍪 Cookies recibidas: \(session.cookies.count)")

            pendingSession = session

            let practicos = try await practicosIndexService.fetchPracticos(session: session)

            practicosParana = practicos
                .filter { normalizeCompany($0.company).contains("PRACTICOS DEL PARANA") }
                .sorted { $0.name < $1.name }

            if let current = practicosParana.first(where: {
                normalizePilotName($0.name) == normalizePilotName(sessionStore.highlightedPilotName)
            }) {
                selectedPilotName = current.name
            } else {
                selectedPilotName = practicosParana.first?.name ?? ""
            }

            if practicosParana.isEmpty {
                errorMessage = "No se encontraron prácticos de Prácticos del Paraná."
            }

        } catch {
            print("❌ Error login/lista prácticos: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            pendingSession = nil
        }
    }

    func finishLogin(sessionStore: SessionStore) async {
        let cleanPilotName = normalizePilotName(selectedPilotName)

        guard !cleanPilotName.isEmpty else {
            errorMessage = "Seleccioná un práctico."
            return
        }

        guard let session = pendingSession else {
            errorMessage = "La sesión no está disponible. Ingresá nuevamente."
            practicosParana = []
            selectedPilotName = ""
            return
        }

        let cleanUsername = normalizeCredential(username)
        let cleanPassword = normalizeCredential(password)

        sessionStore.saveCredentials(username: cleanUsername, password: cleanPassword)
        sessionStore.savePilotName(cleanPilotName)
        sessionStore.saveSession(session)

        await sessionStore.registerPushIfPossible()
    }

    private func normalizeCredential(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizePilotName(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizeCompany(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
