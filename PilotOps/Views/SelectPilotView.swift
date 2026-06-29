import SwiftUI

struct SelectPilotView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var practicosParana: [PracticoEmpresa] = []
    @State private var selectedPilotName: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let practicosIndexService = PracticosIndexService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("Cambiar práctico")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Seleccioná el práctico asociado a este iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if isLoading {
                    ProgressView("Cargando prácticos...")
                        .padding()
                }

                if !practicosParana.isEmpty {
                    Picker("Práctico", selection: $selectedPilotName) {
                        ForEach(practicosParana, id: \.name) { practico in
                            Text(practico.name)
                                .tag(practico.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Button {
                    saveSelectedPilot()
                } label: {
                    Text("Guardar práctico")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isLoading ||
                    selectedPilotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Práctico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPracticos()
            }
        }
    }

    private func loadPracticos() async {
        guard let session = sessionStore.currentSession else {
            errorMessage = "No hay sesión activa. Ingresá nuevamente."
            return
        }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let practicos = try await practicosIndexService.fetchPracticos(session: session)

            practicosParana = practicos
                .filter { normalizeCompany($0.company).contains("PRACTICOS DEL PARANA") }
                .sorted { $0.name < $1.name }

            if let current = practicosParana.first(where: {
                normalizePilotName($0.name) == normalizePilotName(sessionStore.highlightedPilotName)
            }) {
                selectedPilotName = current.name
            } else {
                selectedPilotName = practicosParana.first?.name ?? ""
            }

            if practicosParana.isEmpty {
                errorMessage = "No se encontraron prácticos de Prácticos del Paraná."
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSelectedPilot() {
        let cleanName = normalizePilotName(selectedPilotName)

        guard !cleanName.isEmpty else {
            errorMessage = "Seleccioná un práctico."
            return
        }

        sessionStore.savePilotName(cleanName)

        Task {
            await sessionStore.registerPushIfPossible()
        }

        dismiss()
    }

    private func normalizePilotName(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizeCompany(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
