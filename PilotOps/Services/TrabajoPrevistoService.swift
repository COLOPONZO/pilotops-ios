import Foundation
import SwiftSoup

enum TrabajoPrevistoError: LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case emptyData
    case parseError
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de TrabajoPrevistooOperador no es válida."
        case .networkError:
            return "No se pudo obtener TrabajoPrevistooOperador."
        case .invalidResponse:
            return "La respuesta del servidor no fue válida."
        case .emptyData:
            return "La página TrabajoPrevistooOperador vino vacía."
        case .parseError:
            return "No se pudo interpretar TrabajoPrevistooOperador."
        case .sessionExpired:
            return "Sesión expirada. Ingrese nuevamente."
        }
    }
}

final class TrabajoPrevistoService {
    private let session = NetworkSession.shared.session

    func fetchTrabajosPrevistos(session userSession: UserSession) async throws -> [TrabajoPrevisto] {
        guard let url = URL(string: "https://operacionesportuariasnew.ddns.net/Transacciones/TrabajoPrevistooOperador") else {
            throw TrabajoPrevistoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrabajoPrevistoError.invalidResponse
        }

        let finalURL = httpResponse.url?.absoluteString ?? ""

        print("📄 TrabajoPrevisto HTTP status: \(httpResponse.statusCode)")
        print("🌍 URL final TrabajoPrevisto: \(finalURL)")

        guard 200..<400 ~= httpResponse.statusCode else {
            throw TrabajoPrevistoError.networkError
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw TrabajoPrevistoError.emptyData
        }

        let lowerURL = finalURL.lowercased()
        let lowerHTML = html.lowercased()

        if lowerURL.contains("/account/login") ||
            (lowerHTML.contains("nombre usuario") && lowerHTML.contains("clave")) {
            throw TrabajoPrevistoError.sessionExpired
        }

        let doc = try SwiftSoup.parse(html)
        let tables = try doc.select("table")

        print("📊 Tablas encontradas en TrabajoPrevisto: \(tables.count)")

        // Buscamos la primera tabla de trabajos válidos.
        // Según tu descripción, la primera pestaña es Prácticos del Paraná,
        // así que tomamos la primera tabla grande con encabezados de trabajos.
        for (tableIndex, table) in tables.array().enumerated() {
            let rows = try table.select("tr")
            guard rows.count >= 2 else { continue }

            let headerCells = try rows[0].select("th, td")
            let headers = try headerCells.array().map { normalizeHeader(try $0.text()) }

            print("📊 Tabla \(tableIndex) encabezados: \(headers)")

            guard let numeroIndex = indexMatching(headers, candidates: ["NRO BUQUE", "NRO", "NUMERO BUQUE"]),
                  let buqueIndex = indexMatching(headers, candidates: ["BUQUE"]),
                  let muelleDesdeIndex = indexMatching(headers, candidates: ["MUELLE DESDE"]),
                  let muelleHastaIndex = indexMatching(headers, candidates: ["MUELLE HASTA"]),
                  let horaInicioIndex = indexMatching(headers, candidates: ["H. ESTIMA. INICIO", "H ESTIMA INICIO", "HORA ESTIMADA INICIO"]) else {
                continue
            }

            var resultados: [TrabajoPrevisto] = []

            for row in rows.array().dropFirst() {
                let cells = try row.select("td")
                if cells.isEmpty { continue }

                let values = try cells.array().map {
                    try $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                }

                guard values.indices.contains(numeroIndex),
                      values.indices.contains(buqueIndex),
                      values.indices.contains(muelleDesdeIndex),
                      values.indices.contains(muelleHastaIndex),
                      values.indices.contains(horaInicioIndex) else {
                    continue
                }

                let numeroBuque = values[numeroIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                let buque = values[buqueIndex].trimmingCharacters(in: .whitespacesAndNewlines)

                // Saltar filas vacías o filas no reales
                if numeroBuque.isEmpty || buque.isEmpty { continue }

                let item = TrabajoPrevisto(
                    numeroBuque: numeroBuque,
                    buque: buque,
                    muelleDesde: values[muelleDesdeIndex].trimmingCharacters(in: .whitespacesAndNewlines),
                    muelleHasta: values[muelleHastaIndex].trimmingCharacters(in: .whitespacesAndNewlines),
                    horaEstimadaInicio: values[horaInicioIndex].trimmingCharacters(in: .whitespacesAndNewlines),
                    empresa: "PRACTICOS DEL PARANA"
                )

                resultados.append(item)
            }

            if !resultados.isEmpty {
                print("✅ Trabajos previstos detectados en primera pestaña: \(resultados.count)")
                return resultados
            }
        }

        throw TrabajoPrevistoError.parseError
    }

    private func indexMatching(_ headers: [String], candidates: [String]) -> Int? {
        headers.firstIndex { header in
            candidates.contains(where: { candidate in
                header == candidate || header.contains(candidate)
            })
        }
    }

    private func normalizeHeader(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
