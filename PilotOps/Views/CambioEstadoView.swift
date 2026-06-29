import SwiftUI
import Combine

struct CambioEstadoView: View {

    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var vm = CambioEstadoViewModel()
    @State private var timer = Timer.publish(every: 180, on: .main, in: .common).autoconnect()
    @State private var showSelectPilot = false

    @AppStorage("minimizedProcesoKeys") private var minimizedProcesoKeysRaw: String = ""

    private var minimizedProcesoKeys: Set<String> {
        Set(minimizedProcesoKeysRaw.split(separator: "|").map(String.init))
    }

    private var visibleProcesoItems: [PracticoEstado] {
        vm.enProceso.filter { !minimizedProcesoKeys.contains(procesoKey($0)) }
    }

    private var minimizedProcesoItems: [PracticoEstado] {
        vm.enProceso.filter { minimizedProcesoKeys.contains(procesoKey($0)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                if vm.didStatusChange {
                    statusChangeBanner
                }

                if let mine = vm.myStatus(name: sessionStore.highlightedPilotName) {
                    myStatusCard(mine)
                }

                if vm.isLoading {
                    ProgressView("Cargando estado...")
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

                statusSection(
                    title: "En espera",
                    count: vm.enEsperaParana.count,
                    items: vm.enEsperaParana
                )

                procesoSection(
                    title: "T. Proceso",
                    count: visibleProcesoItems.count,
                    items: visibleProcesoItems
                )

                minimizedProcesoSection(
                    title: "Trabajos minimizados",
                    count: minimizedProcesoItems.count,
                    items: minimizedProcesoItems
                )
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Estado Operativo")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Actualizar") {
                    Task {
                        await vm.load(sessionStore: sessionStore, silent: true)
                    }
                }

                Button("Cambiar práctico") {
                    showSelectPilot = true
                }
            }
        }
        .sheet(isPresented: $showSelectPilot) {
            SelectPilotView()
                .environmentObject(sessionStore)
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

    private var statusChangeBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cambio de estado detectado")
                        .font(.headline)
                        .fontWeight(.bold)

                    if let previous = vm.previousStatus,
                       let current = vm.currentStatus {
                        Text("\(previous) → \(current)")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                Button {
                    vm.dismissStatusChangeAlert()
                } label: {
                    Text("Cerrar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }

    private func myStatusCard(_ mine: PracticoEstado) -> some View {
        let position = vm.myQueuePosition(name: sessionStore.highlightedPilotName)
        let myProcesoInfo = vm.muellesForProceso(sessionStore.highlightedPilotName)

        return VStack(alignment: .leading, spacing: 10) {

            Text("Mi práctico")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(sessionStore.highlightedPilotName)
                .font(.title3)
                .fontWeight(.semibold)

            HStack(spacing: 10) {
                Circle()
                    .fill(colorForStatus(mine.status))
                    .frame(width: 12, height: 12)

                Text(mine.status)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(colorForStatus(mine.status))
            }

            if mine.status == "T. PROCESO" {
                Text("Buque asignado: \(formattedBuque(myProcesoInfo?.buque))")
                    .font(.headline)
            }

            if let pos = position {
                Text("Posición: \(pos.position) de \(pos.total)")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if let date = mine.changeDate {
                Text("Último cambio: \(date)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let updated = vm.lastUpdated {
                Text("Actualizado: \(formattedDate(updated))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let company = vm.companyFor(sessionStore.highlightedPilotName) {
                Text(company)
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

    private func statusSection(title: String, count: Int, items: [PracticoEstado]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(title) (\(count))")
                    .font(.headline)
                Spacer()
            }

            if items.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { practico in
                        esperaRow(practico)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func procesoSection(title: String, count: Int, items: [PracticoEstado]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(title) (\(count))")
                    .font(.headline)
                Spacer()
            }

            if items.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { practico in
                        procesoRow(practico, isMinimized: false)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func minimizedProcesoSection(title: String, count: Int, items: [PracticoEstado]) -> some View {
        Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(title) (\(count))")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Mostrar todos") {
                            restoreAllProceso()
                        }
                        .font(.caption)
                    }

                    VStack(spacing: 8) {
                        ForEach(items) { practico in
                            minimizedProcesoRow(practico)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var emptyCard: some View {
        Text("Sin registros")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func esperaRow(_ practico: PracticoEstado) -> some View {
        let isMe = normalize(practico.name) == normalize(sessionStore.highlightedPilotName)

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(colorForStatus(practico.status))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(practico.name)
                        .font(.body)
                        .fontWeight(isMe ? .bold : .regular)

                    if isMe {
                        Text("VOS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }

    private func procesoRow(_ practico: PracticoEstado, isMinimized: Bool) -> some View {
        let isMe = normalize(practico.name) == normalize(sessionStore.highlightedPilotName)
        let info = vm.muellesForProceso(practico.name)

        return VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedBuque(info?.buque))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("Hora asignada: \(formattedHorario(info?.horario))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Minimizar") {
                    minimizeProceso(practico)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text(practico.name)
                    .font(.body)
                    .fontWeight(isMe ? .bold : .medium)

                if isMe {
                    Text("VOS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()
            }

            Text("\(formattedMuelle(info?.muelleDesde)) → \(formattedMuelle(info?.muelleHasta))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
    }

    private func minimizedProcesoRow(_ practico: PracticoEstado) -> some View {
        let info = vm.muellesForProceso(practico.name)

        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(formattedBuque(info?.buque))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(practico.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Mostrar") {
                restoreProceso(practico)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func procesoKey(_ practico: PracticoEstado) -> String {
        let info = vm.muellesForProceso(practico.name)

        return [
            normalize(practico.name),
            normalize(info?.buque ?? ""),
            normalize(info?.horario ?? "")
        ]
        .joined(separator: "#")
    }

    private func minimizeProceso(_ practico: PracticoEstado) {
        var keys = minimizedProcesoKeys
        keys.insert(procesoKey(practico))
        minimizedProcesoKeysRaw = keys.sorted().joined(separator: "|")
    }

    private func restoreProceso(_ practico: PracticoEstado) {
        var keys = minimizedProcesoKeys
        keys.remove(procesoKey(practico))
        minimizedProcesoKeysRaw = keys.sorted().joined(separator: "|")
    }

    private func restoreAllProceso() {
        minimizedProcesoKeysRaw = ""
    }

    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "EN ESPERA":
            return .green
        case "T. PROCESO":
            return .blue
        case "DE FRANCO":
            return .gray
        default:
            return .secondary
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

    private func formattedBuque(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Buque no disponible"
        }
        return value
    }

    private func formattedHorario(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "-"
        }
        return value
    }

    private func formattedMuelle(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "-"
        }
        return value
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
