import Foundation
import Combine

@MainActor
final class TrabajosViewModel: ObservableObject {
    @Published var trabajos: [TrabajoPrevisto] = []
    @Published var estados: [PracticoEstado] = []
    @Published var practicosIndex: [PracticoEmpresa] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let trabajoPrevistoService = TrabajoPrevistoService()
    private let cambioEstadoService = CambioEstadoServices()
    private let practicosIndexService = PracticosIndexService()

    func load(sessionStore: SessionStore, silent: Bool = false) async {
        guard let session = sessionStore.currentSession else {
            errorMessage = "No hay sesión iniciada."
            return
        }

        let shouldShowLoading = !silent && trabajos.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = nil

        defer { isLoading = false }

        do {
            async let trabajosData = trabajoPrevistoService.fetchTrabajosPrevistos(session: session)
            async let estadosData = cambioEstadoService.fetchEstados(session: session)
            async let practicosData = practicosIndexService.fetchPracticos(session: session)

            let (trabajosResult, estadosResult, practicosResult) = try await (trabajosData, estadosData, practicosData)

            trabajos = trabajosResult.sorted {
                let lhs = Int($0.numeroBuque) ?? 9999
                let rhs = Int($1.numeroBuque) ?? 9999
                return lhs < rhs
            }

            estados = estadosResult
            practicosIndex = practicosResult.sorted { $0.name < $1.name }
            lastUpdated = Date()

        } catch {
            print("❌ Error en TrabajosViewModel.load: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func myQueuePosition(name: String) -> (position: Int, total: Int)? {
        let normalized = normalize(name)
        let lista = enEsperaParana

        guard let index = lista.firstIndex(where: {
            normalize($0.name) == normalized
        }) else {
            return nil
        }

        return (index + 1, lista.count)
    }

    private var enEsperaParana: [PracticoEstado] {
        let paranaNames = Set(
            practicosIndex
                .filter { $0.company.contains("PRACTICOS DEL PARANA") }
                .map { normalize($0.name) }
        )

        return estados
            .filter { $0.status == "EN ESPERA" && paranaNames.contains(normalize($0.name)) }
            .sorted { ($0.queuePosition ?? 9999) < ($1.queuePosition ?? 9999) }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
