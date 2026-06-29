import Foundation
import SwiftSoup

enum LoginError: LocalizedError {
    case invalidCredentials
    case loginPageUnavailable
    case missingFormFields
    case missingLoginForm
    case serverError(String)
    case authenticationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Usuario o contraseña incorrectos."
        case .loginPageUnavailable:
            return "No se pudo abrir la página de login."
        case .missingFormFields:
            return "No se pudieron obtener los campos necesarios del formulario."
        case .missingLoginForm:
            return "No se encontró el formulario de login."
        case .serverError(let message):
            return "Error del servidor: \(message)"
        case .authenticationFailed:
            return "No se pudo validar la sesión después del login."
        case .unknown:
            return "Ocurrió un error desconocido."
        }
    }
}

final class LoginService {
    private let baseURL = URL(string: "https://operacionesportuariasnew.ddns.net")!
    private let session = NetworkSession.shared.session

    func login(username: String, password: String) async throws -> UserSession {
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUser.isEmpty, !trimmedPass.isEmpty else {
            throw LoginError.invalidCredentials
        }

        // Limpiar cookies previas
        HTTPCookieStorage.shared.cookies?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }

        // 1) GET de la página inicial para obtener el formulario real y sus hidden fields
        let loginPageURL = baseURL
        var getRequest = URLRequest(url: loginPageURL)
        getRequest.httpMethod = "GET"

        let (loginPageData, loginPageResponse) = try await session.data(for: getRequest)

        guard let httpResponse = loginPageResponse as? HTTPURLResponse,
              200..<400 ~= httpResponse.statusCode else {
            throw LoginError.loginPageUnavailable
        }

        guard let html = String(data: loginPageData, encoding: .utf8), !html.isEmpty else {
            throw LoginError.loginPageUnavailable
        }

        let formInfo = try extractLoginFormInfo(from: html)

        // 2) POST al action real del formulario
        var postRequest = URLRequest(url: formInfo.actionURL)
        postRequest.httpMethod = "POST"
        postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        postRequest.httpBody = formInfo.payload(username: trimmedUser, password: trimmedPass).data(using: .utf8)

        let (postData, postResponse) = try await session.data(for: postRequest)

        guard let postHTTP = postResponse as? HTTPURLResponse else {
            throw LoginError.unknown
        }

        if !(200..<400).contains(postHTTP.statusCode) {
            throw LoginError.serverError("HTTP \(postHTTP.statusCode)")
        }

        let cookies = HTTPCookieStorage.shared.cookies ?? []
        print("🍪 Cookies luego de login: \(cookies.count)")
        print("🌍 URL final post-login: \(postHTTP.url?.absoluteString ?? "sin url")")
        print("📄 HTML post-login length: \(postData.count)")

        // 3) Verificación real abriendo una página protegida
        try await verifyAuthenticatedSession()

        return UserSession(
            username: trimmedUser,
            cookies: cookies,
            loginDate: Date()
        )
    }

    // MARK: - Validación de sesión

    private func verifyAuthenticatedSession() async throws {
        guard let protectedURL = URL(string: "https://operacionesportuariasnew.ddns.net/Practicos/CambioEstado") else {
            throw LoginError.authenticationFailed
        }

        var request = URLRequest(url: protectedURL)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LoginError.authenticationFailed
        }

        let finalURL = httpResponse.url?.absoluteString ?? ""
        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw LoginError.authenticationFailed
        }

        let lowerURL = finalURL.lowercased()
        let lowerHTML = html.lowercased()

        print("🌍 URL validación: \(finalURL)")
        print("📄 HTML validación length: \(html.count)")

        // Si vuelve explícitamente al login, falló autenticación
        let definitelyLogin =
            lowerURL.contains("/account/login") &&
            (lowerHTML.contains("nombre usuario") ||
             lowerHTML.contains("clave") ||
             lowerHTML.contains("iniciar sesion") ||
             lowerHTML.contains("login"))

        if definitelyLogin {
            throw LoginError.invalidCredentials
        }

        // Señales de página protegida real
        let looksLikeProtectedPage =
            lowerHTML.contains("en espera") ||
            lowerHTML.contains("de franco") ||
            lowerHTML.contains("t. proceso") ||
            lowerHTML.contains("cambio estado") ||
            lowerHTML.contains("volver a pizarra") ||
            lowerHTML.contains("practicos")

        if !looksLikeProtectedPage {
            throw LoginError.authenticationFailed
        }

        print("✅ Sesión validada correctamente contra CambioEstado")
    }

    // MARK: - Extracción del formulario real

    private struct LoginFormInfo {
        let actionURL: URL
        let params: [String: String]
        let userField: String
        let passField: String
        let submitField: String?
        let submitValue: String?

        func payload(username: String, password: String) -> String {
            var finalParams = params
            finalParams[userField] = username
            finalParams[passField] = password

            if let submitField {
                finalParams[submitField] = submitValue ?? "Ingresar"
            }

            return finalParams
                .map { key, value in
                    let escapedKey = urlEncode(key)
                    let escapedValue = urlEncode(value)
                    return "\(escapedKey)=\(escapedValue)"
                }
                .joined(separator: "&")
        }

        private func urlEncode(_ string: String) -> String {
            string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
                .replacingOccurrences(of: "+", with: "%2B")
                .replacingOccurrences(of: "&", with: "%26")
                .replacingOccurrences(of: "=", with: "%3D")
                ?? string
        }
    }

    private func extractLoginFormInfo(from html: String) throws -> LoginFormInfo {
        let doc: Document = try SwiftSoup.parse(html)

        guard let form = try doc.select("form").first() else {
            throw LoginError.missingLoginForm
        }

        let action = try form.attr("action")
        let actionURL = resolveActionURL(action)

        var params: [String: String] = [:]

        let hiddenInputs = try form.select("input[type=hidden]")
        for input in hiddenInputs {
            let name = try input.attr("name")
            let value = try input.attr("value")
            if !name.isEmpty {
                params[name] = value
            }
        }

        let allInputs = try form.select("input")
        var userFieldName: String?
        var passwordFieldName: String?
        var submitFieldName: String?
        var submitFieldValue: String?

        for input in allInputs {
            let type = try input.attr("type").lowercased()
            let name = try input.attr("name")
            let value = try input.attr("value")

            if type == "password", !name.isEmpty {
                passwordFieldName = name
            }

            if (type == "text" || type == "email"), !name.isEmpty, userFieldName == nil {
                userFieldName = name
            }

            if (type == "submit" || type == "button"), !name.isEmpty, submitFieldName == nil {
                submitFieldName = name
                submitFieldValue = value
            }
        }

        guard let userField = userFieldName,
              let passField = passwordFieldName else {
            throw LoginError.missingFormFields
        }

        return LoginFormInfo(
            actionURL: actionURL,
            params: params,
            userField: userField,
            passField: passField,
            submitField: submitFieldName,
            submitValue: submitFieldValue
        )
    }

    private func resolveActionURL(_ action: String) -> URL {
        let trimmed = action.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return baseURL
        }

        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }

        if trimmed.hasPrefix("/") {
            return baseURL.appending(path: String(trimmed.dropFirst()))
        } else {
            return baseURL.appending(path: trimmed)
        }
    }
}
