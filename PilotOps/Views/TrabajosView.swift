import SwiftUI
import Combine

struct TrabajosView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var vm = TrabajosViewModel()
    @State private var timer = Timer.publish(every: 180, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                headerCard

                if vm.isLoading {
                    ProgressView("Cargando buques previstos...")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 2)
                        .padding(.horizontal)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 2)
                        .padding(.horizontal)
                }

                if !vm.isLoading && vm.errorMessage == nil {
                    trabajosSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trabajos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Actualizar") {
                    Task {
                        await vm.load(sessionStore: sessionStore, silent: true)
                    }
                }
            }
        }
        .task {
            await vm.load(sessionStore: sessionStore)
        }
        .refreshable {
            await vm.load(sessionStore: sessionStore, silent: true)
        }
        .onReceive(timer) { _ in
            Task {
                await vm.load(sessionStore: sessionStore, silent: true)
            }
        }
    }

    private var headerCard: some View {
        let queue = vm.myQueuePosition(name: sessionStore.highlightedPilotName)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Buques previstos")
                .font(.headline)

            if let queue {
                Text("Posición en espera: \(queue.position) de \(queue.total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No estás en espera")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Cantidad: \(vm.trabajos.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let updated = vm.lastUpdated {
                Text("Actualizado: \(formattedDate(updated))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.horizontal)
    }

    private var trabajosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if vm.trabajos.isEmpty {
                Text("Sin registros")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.trabajos) { trabajo in
                        trabajoRow(trabajo)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func trabajoRow(_ trabajo: TrabajoPrevisto) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text("Nro: \(trabajo.numeroBuque)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(trabajo.horaEstimadaInicio)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            Text(trabajo.buque)
                .font(.headline)

            Divider()

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Muelle desde")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trabajo.muelleDesde.isEmpty ? "-" : trabajo.muelleDesde)
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Muelle hasta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trabajo.muelleHasta.isEmpty ? "-" : trabajo.muelleHasta)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
