import Foundation

struct PracticoEstado: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let status: String
    let changeDate: String?
    let processDate: String?
    let queuePosition: Int?
}
