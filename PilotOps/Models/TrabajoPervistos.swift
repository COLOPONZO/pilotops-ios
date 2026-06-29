import Foundation

struct TrabajoPrevisto: Identifiable, Hashable {
    let id = UUID()
    let numeroBuque: String
    let buque: String
    let muelleDesde: String
    let muelleHasta: String
    let horaEstimadaInicio: String
    let empresa: String
}
