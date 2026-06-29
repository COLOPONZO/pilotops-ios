import Foundation
import SwiftSoup

enum CambioEstadoError: LocalizedError, Equatable {
    case invalidURL
    case networkError
    case invalidResponse
    case emptyData
    case parseError
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de CambioEstado no es válida."
        case .networkError:
            return "No se pudo obtener CambioEstado."
        case .invalidResponse:
            return "La respuesta del servidor no fue válida."
        case .emptyData:
            return "La página CambioEstado vino vacía."
        case .parseError:
            return "No se pudo interpretar Cambio de Estado."
        case .sessionExpired:
            return "Sesión expirada. Ingrese nuevamente."
        }
    }
}

final class CambioEstadoServices {
    private let session = NetworkSession.shared.session

    func fetchEstados(session userSession: UserSession) async throws -> [PracticoEstado] {
        guard let url = URL(string: "https://operacionesportuariasnew.ddns.net/Practicos/CambioEstado") else {
            throw CambioEstadoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CambioEstadoError.invalidResponse
        }

        let finalURL = httpResponse.url?.absoluteString ?? ""

        print("📄 CambioEstado HTTP status: \(httpResponse.statusCode)")
        print("🌍 URL final CambioEstado: \(finalURL)")

        guard 200..<400 ~= httpResponse.statusCode else {
            throw CambioEstadoError.networkError
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw CambioEstadoError.emptyData
        }

        print("📄 CambioEstado HTML length: \(html.count)")

        let doc = try SwiftSoup.parse(html)
        let title = try doc.title()
        let bodyText = try doc.body()?.text() ?? ""

        print("🏷️ Title CambioEstado: \(title)")
        print("📝 Body preview CambioEstado: \(String(bodyText.prefix(200)))")

        // SOLO considerar sesión expirada si hay señales muy claras
        let lowerURL = finalURL.lowercased()
        let lowerTitle = title.lowercased()
        let lowerBody = bodyText.lowercased()

        let definitelyLogin =
            lowerURL.contains("/account/login") ||
            lowerTitle.contains("login") ||
            lowerTitle.contains("iniciar sesion") ||
            (lowerBody.contains("nombre usuario") && lowerBody.contains("clave"))

        if definitelyLogin {
            throw CambioEstadoError.sessionExpired
        }

        let tables = try doc.select("table")
        print("📊 Tablas encontradas en CambioEstado: \(tables.count)")

        var results: [PracticoEstado] = []
        var enEsperaCounter = 0

        for table in tables {
            let rows = try table.select("tr")

            for row in rows {
                let cells = try row.select("td")
                if cells.count < 5 { continue }

                let values = try cells.array().map {
                    try $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                }

                let joined = values.joined(separator: " ").uppercased()

                if joined.contains("ESPERA") ||
                    joined.contains("FRANCO") ||
                    joined.contains("PROCESO") {

                    let name = normalizeName(values[0])
                    let changeDate = values.count > 2 && !values[2].isEmpty ? values[2] : nil
                    let processDate = values.count > 3 && !values[3].isEmpty ? values[3] : nil
                    let status = normalizeStatus(values[4])

                    guard !name.isEmpty, !status.isEmpty else { continue }

                    var queuePosition: Int? = nil
                    if status == "EN ESPERA" {
                        enEsperaCounter += 1
                        queuePosition = enEsperaCounter
                    }

                    results.append(
                        PracticoEstado(
                            name: name,
                            status: status,
                            changeDate: changeDate,
                            processDate: processDate,
                            queuePosition: queuePosition
                        )
                    )
                }
            }
        }

        print("✅ Practicos detectados en CambioEstado: \(results.count)")

        guard !results.isEmpty else {
            throw CambioEstadoError.parseError
        }

        return results
    }

    private func normalizeName(_ name: String) -> String {
        name
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeStatus(_ status: String) -> String {
        let normalized = status
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("PROCESO") {
            return "T. PROCESO"
        } else if normalized.contains("ESPERA") {
            return "EN ESPERA"
        } else if normalized.contains("FRANCO") {
            return "DE FRANCO"
        } else {
            return ""
        }
    }
}
