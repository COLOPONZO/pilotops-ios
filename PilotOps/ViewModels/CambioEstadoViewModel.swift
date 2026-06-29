import Foundation
import Combine

@MainActor
final class CambioEstadoViewModel: ObservableObject {
    
    @Published var estados: [PracticoEstado] = []
    @Published var practicosIndex: [PracticoEmpresa] = []
    @Published var trabajosProceso: [TrabajoProcesoInfo] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    
    @Published var lastKnownStatus: String?
    @Published var didStatusChange: Bool = false
    @Published var previousStatus: String?
    @Published var currentStatus: String?
    
    @Published var didReachFirstPosition: Bool = false
    
    private var lastKnownQueuePosition: Int?
    
    private let cambioEstadoService = CambioEstadoServices()
    private let practicosIndexService = PracticosIndexService()
    private let trabajoProcesoService = TrabajoProcesoService()
    
    func load(sessionStore: SessionStore, silent: Bool = false) async {
        guard let session = sessionStore.currentSession else {
            errorMessage = "No hay sesión iniciada."
            return
        }
        
        let shouldShowLoading = !silent && estados.isEmpty
        if shouldShowLoading {
            isLoading = true
        }
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            async let estadosData = cambioEstadoService.fetchEstados(session: session)
            async let practicosData = practicosIndexService.fetchPracticos(session: session)
            
            let estadosResult = try await estadosData
            let practicosResult = try await practicosData
            
            estados = estadosResult
            practicosIndex = practicosResult.sorted { $0.name < $1.name }
            lastUpdated = Date()
            
            do {
                let trabajosResult = try await trabajoProcesoService.fetchTrabajosProceso(session: session)
                trabajosProceso = trabajosResult
            } catch {
                print("⚠️ TrabajoProcesoOperador no disponible: \(error.localizedDescription)")
                trabajosProceso = []
            }
            
            handleStatusNotifications(for: sessionStore.highlightedPilotName)
            handleQueueNotifications(for: sessionStore.highlightedPilotName)
            
        } catch {
            print("❌ Error en CambioEstadoViewModel.load: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    func dismissStatusChangeAlert() {
        didStatusChange = false
    }
    
    func myStatus(name: String) -> PracticoEstado? {
        let normalizedSearch = normalize(name)
        return estados.first { normalize($0.name) == normalizedSearch }
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
    
    var enEsperaParana: [PracticoEstado] {
        let paranaNames = Set(
            practicosIndex
                .filter { normalize($0.company).contains("PRACTICOS DEL PARANA") }
                .map { normalize($0.name) }
        )
        
        return estados
            .filter { $0.status == "EN ESPERA" && paranaNames.contains(normalize($0.name)) }
            .sorted { ($0.queuePosition ?? 9999) < ($1.queuePosition ?? 9999) }
    }
    
    var enProceso: [PracticoEstado] {
        estados
            .filter { $0.status == "T. PROCESO" }
            .sorted {
                let h1 = muellesForProceso($0.name)?.horario ?? ""
                let h2 = muellesForProceso($1.name)?.horario ?? ""
                return h1 < h2
            }
    }
    
    func muellesForProceso(_ practicoName: String) -> TrabajoProcesoInfo? {
        let target = normalize(practicoName)
        return trabajosProceso.first { normalize($0.practicoName) == target }
    }

    func companyFor(_ practicoName: String) -> String? {
        let target = normalize(practicoName)
        return practicosIndex.first { normalize($0.name) == target }?.company
    }

    private func handleStatusNotifications(for practicoName: String) {
        guard let current = myStatus(name: practicoName)?.status else { return }

        if let previous = lastKnownStatus, previous != current {
            previousStatus = previous
            currentStatus = current
            didStatusChange = true

            print("🔔 CAMBIO DE ESTADO: \(previous) → \(current)")
            NotificationService.shared.sendStatusChangeNotification(from: previous, to: current)

            if previous == "EN ESPERA" && current == "T. PROCESO" {
                NotificationService.shared.sendAssignedToProcessNotification(practicoName: practicoName)
            }
        } else {
            currentStatus = current
        }

        lastKnownStatus = current
    }

    private func handleQueueNotifications(for practicoName: String) {
        if let queue = myQueuePosition(name: practicoName) {
            let currentPosition = queue.position

            if currentPosition == 1 && lastKnownQueuePosition != 1 {
                didReachFirstPosition = true
                NotificationService.shared.sendFirstPositionNotification(practicoName: practicoName)
            } else {
                didReachFirstPosition = false
            }

            lastKnownQueuePosition = currentPosition
        } else {
            didReachFirstPosition = false
            lastKnownQueuePosition = nil
        }
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
