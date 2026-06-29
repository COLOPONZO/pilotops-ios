import Foundation

final class PushRegistrationService {
    static let shared = PushRegistrationService()

    private init() {}

    private let serverURL = URL(string: "http://163.176.53.137:55050/register_device")!

    func registerDevice(practico: String, deviceToken: String) async {
        let cleanPractico = practico
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        let cleanToken = deviceToken
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanPractico.isEmpty, !cleanToken.isEmpty else {
            print("⚠️ Registro push omitido: práctico o token vacío")
            return
        }

        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let payload: [String: String] = [
            "practico": cleanPractico,
            "device_token": cleanToken
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("📡 Registro push HTTP status:", http.statusCode)
            }

            if let text = String(data: data, encoding: .utf8) {
                print("📡 Registro push respuesta:", text)
            }

        } catch {
            print("❌ Error registrando device en Oracle:", error.localizedDescription)
        }
    }
}
