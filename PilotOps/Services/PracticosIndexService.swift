import Foundation
import SwiftSoup

enum PracticosIndexError: LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case emptyData
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL de Practicos/Index no es válida."
        case .networkError:
            return "No se pudo obtener Practicos/Index."
        case .invalidResponse:
            return "La respuesta del servidor no fue válida."
        case .emptyData:
            return "La página Practicos/Index vino vacía."
        case .parseError:
            return "No se pudo interpretar Practicos/Index."
        }
    }
}

final class PracticosIndexService {
    private let session = NetworkSession.shared.session

    func fetchPracticos(session userSession: UserSession) async throws -> [PracticoEmpresa] {
        guard let url = URL(string: "https://operacionesportuariasnew.ddns.net/Practicos/Index") else {
            throw PracticosIndexError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PracticosIndexError.invalidResponse
        }

        print("📄 PracticosIndex HTTP status: \(httpResponse.statusCode)")
        print("🌍 URL final PracticosIndex: \(httpResponse.url?.absoluteString ?? "sin url")")

        guard 200..<400 ~= httpResponse.statusCode else {
            throw PracticosIndexError.networkError
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw PracticosIndexError.emptyData
        }

        let doc = try SwiftSoup.parse(html)
        let tables = try doc.select("table")

        print("📊 Tablas encontradas en PracticosIndex: \(tables.count)")

        var results: [PracticoEmpresa] = []

        for (tableIndex, table) in tables.array().enumerated() {
            let rows = try table.select("tr")
            print("📊 Tabla PracticosIndex \(tableIndex): \(rows.count) filas")

            for row in rows {
                let cells = try row.select("td")
                if cells.count < 2 { continue }

                let values = try cells.array().map {
                    try $0.text().trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Ajuste genérico:
                // buscamos filas que tengan nombre de práctico + empresa
                // y evitamos filas vacías
                guard values.count >= 2 else { continue }

                // Intentamos encontrar empresa por texto conocido
                let joined = values.joined(separator: " | ")
                if joined.uppercased().contains("PRACTICOS") || joined.uppercased().contains("PILOTS") {
                    print("➡️ PracticosIndex detectado: \(values)")
                }

                // Heurística inicial:
                // asumimos que una columna contiene nombre y otra empresa.
                // más abajo refinamos según lo que devuelva la consola.
                let possibleName = values.first(where: { looksLikeName($0) }) ?? ""
                let possibleCompany = values.first(where: { looksLikeCompany($0) }) ?? ""

                if !possibleName.isEmpty && !possibleCompany.isEmpty {
                    results.append(
                        PracticoEmpresa(
                            name: normalizeName(possibleName),
                            company: normalizeCompany(possibleCompany)
                        )
                    )
                }
            }
        }

        // eliminar duplicados por nombre, conservando la primera aparición
        var unique: [String: PracticoEmpresa] = [:]
        for item in results {
            if unique[item.name] == nil {
                unique[item.name] = item
            }
        }

        let finalResults = Array(unique.values).sorted { $0.name < $1.name }

        print("✅ PracticosIndex detectados: \(finalResults.count)")

        guard !finalResults.isEmpty else {
            throw PracticosIndexError.parseError
        }

        return finalResults
    }

    private func looksLikeName(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        if t.count < 5 { return false }
        if t.contains("@") { return false }
        if t.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        return true
    }

    private func looksLikeCompany(_ text: String) -> Bool {
        let t = text.uppercased()
        return t.contains("PRACTICOS") || t.contains("PILOTS") || t.contains("PARANA")
    }

    private func normalizeName(_ name: String) -> String {
        name
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeCompany(_ company: String) -> String {
        company
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
