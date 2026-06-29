import Foundation
import SwiftSoup

enum TrabajoProcesoError: LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case emptyData
    case parseError
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de TrabajoProcesoOperador no es válida."
        case .networkError:
            return "No se pudo obtener TrabajoProcesoOperador."
        case .invalidResponse:
            return "La respuesta del servidor no fue válida."
        case .emptyData:
            return "La página TrabajoProcesoOperador vino vacía."
        case .parseError:
            return "No se pudo interpretar TrabajoProcesoOperador."
        case .sessionExpired:
            return "Sesión expirada. Ingrese nuevamente."
        }
    }
}

final class TrabajoProcesoService {
    private let session = NetworkSession.shared.session

    func fetchTrabajosProceso(session userSession: UserSession) async throws -> [TrabajoProcesoInfo] {
        guard let url = URL(string: "https://operacionesportuariasnew.ddns.net/Transacciones/TrabajoProcesoOperador") else {
            throw TrabajoProcesoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TrabajoProcesoError.invalidResponse
        }

        let finalURL = httpResponse.url?.absoluteString ?? ""

        print("📄 TrabajoProceso HTTP status: \(httpResponse.statusCode)")
        print("🌍 URL final TrabajoProceso: \(finalURL)")

        guard 200..<400 ~= httpResponse.statusCode else {
            throw TrabajoProcesoError.networkError
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw TrabajoProcesoError.emptyData
        }

        print("📄 TrabajoProceso HTML length: \(html.count)")

        let lowerURL = finalURL.lowercased()
        let lowerHTML = html.lowercased()

        if lowerURL.contains("/account/login") ||
            (lowerHTML.contains("nombre usuario") && lowerHTML.contains("clave")) {
            throw TrabajoProcesoError.sessionExpired
        }

        let doc = try SwiftSoup.parse(html)
        let title = try doc.title()
        let tables = try doc.select("table")

        print("🏷️ Title TrabajoProceso: \(title)")
        print("📊 Tablas encontradas en TrabajoProceso: \(tables.count)")

        var results: [TrabajoProcesoInfo] = []

        for (tableIndex, table) in tables.array().enumerated() {
            let rows = try table.select("tr")
            guard rows.count >= 2 else { continue }

            let headerCells = try rows[0].select("th, td")
            let headers = try headerCells.array().map { normalizeHeader(try $0.text()) }

            print("📊 Tabla \(tableIndex) encabezados: \(headers)")

            guard let practicoIndex = indexForPractico(in: headers),
                  let buqueIndex = indexForBuque(in: headers),
                  let horarioIndex = indexForHorario(in: headers),
                  let muelleDesdeIndex = indexForMuelleDesde(in: headers),
                  let muelleHastaIndex = indexForMuelleHasta(in: headers) else {
                continue
            }

            var tableResults: [TrabajoProcesoInfo] = []

            for row in rows.array().dropFirst() {
                let cells = try row.select("td")
                if cells.isEmpty { continue }

                let values = try cells.array().map {
                    try $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                }

                guard values.indices.contains(practicoIndex),
                      values.indices.contains(buqueIndex),
                      values.indices.contains(horarioIndex),
                      values.indices.contains(muelleDesdeIndex),
                      values.indices.contains(muelleHastaIndex) else {
                    continue
                }

                let practico = normalizeName(values[practicoIndex])
                let buque = cleanValue(values[buqueIndex])
                let horario = cleanValue(values[horarioIndex])
                let muelleDesde = cleanValue(values[muelleDesdeIndex])
                let muelleHasta = cleanValue(values[muelleHastaIndex])

                if practico.isEmpty { continue }
                if buque.isEmpty && horario.isEmpty && muelleDesde.isEmpty && muelleHasta.isEmpty { continue }

                tableResults.append(
                    TrabajoProcesoInfo(
                        practicoName: practico,
                        buque: buque,
                        horario: horario,
                        muelleDesde: muelleDesde,
                        muelleHasta: muelleHasta
                    )
                )
            }

            if !tableResults.isEmpty {
                print("✅ Trabajos en proceso detectados en tabla \(tableIndex): \(tableResults.count)")
                results.append(contentsOf: tableResults)
            }
        }

        // Eliminar duplicados por nombre de práctico, por si aparece repetido
        var uniqueByPractico: [String: TrabajoProcesoInfo] = [:]
        for item in results {
            uniqueByPractico[item.practicoName] = item
        }

        let finalResults = Array(uniqueByPractico.values)

        guard !finalResults.isEmpty else {
            print("❌ No se pudo detectar una tabla válida en TrabajoProcesoOperador")
            throw TrabajoProcesoError.parseError
        }

        print("✅ Total trabajos en proceso consolidados: \(finalResults.count)")
        return finalResults
    }

    // MARK: - Detección de columnas

    private func indexForPractico(in headers: [String]) -> Int? {
        headers.firstIndex {
            $0.contains("PRACTICO") ||
            $0.contains("PILOTO") ||
            $0 == "NOMBRE" ||
            $0.contains("NOMBRE DEL PRACTICO") ||
            $0.contains("PRACTICO ASIGNADO")
        }
    }

    private func indexForBuque(in headers: [String]) -> Int? {
        headers.firstIndex {
            $0 == "BUQUE" ||
            $0.contains("NOMBRE DEL BUQUE") ||
            $0.contains("NAVE")
        }
    }

    private func indexForHorario(in headers: [String]) -> Int? {
        if let exact = headers.firstIndex(where: {
            $0 == "H. ASIGNADA" ||
            $0 == "H ASIGNADA" ||
            $0 == "HORA ASIGNADA"
        }) {
            return exact
        }

        if let containsHora = headers.firstIndex(where: {
            ($0.contains("H.") || $0.contains("HORA")) && $0.contains("ASIGNADA")
        }) {
            return containsHora
        }

        if let containsGeneralHora = headers.firstIndex(where: {
            $0.contains("HORA") || $0.contains("ETA")
        }) {
            return containsGeneralHora
        }

        return nil
    }

    private func indexForMuelleDesde(in headers: [String]) -> Int? {
        headers.firstIndex {
            ($0.contains("MUELLE") && $0.contains("DESDE")) ||
            $0 == "MUELLE DESDE"
        }
    }

    private func indexForMuelleHasta(in headers: [String]) -> Int? {
        headers.firstIndex {
            ($0.contains("MUELLE") && $0.contains("HASTA")) ||
            $0 == "MUELLE HASTA"
        }
    }

    // MARK: - Normalización

    private func normalizeHeader(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeName(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanValue(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
