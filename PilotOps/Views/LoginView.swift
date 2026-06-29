import SwiftUI

struct LoginView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("PilotOps")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Ingreso inicial")
                .foregroundStyle(.secondary)

            TextField("Usuario", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SecureField("Contraseña", text: $viewModel.password)
                .textContentType(.password)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !viewModel.practicosParana.isEmpty {
                Picker("Mi práctico", selection: $viewModel.selectedPilotName) {
                    ForEach(viewModel.practicosParana, id: \.name) { practico in
                        Text(practico.name)
                            .tag(practico.name)
                    }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("Seleccioná tu práctico desde la lista oficial. El iPhone quedará registrado para recibir notificaciones.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button {
                Task {
                    if viewModel.practicosParana.isEmpty {
                        await viewModel.loginAndLoadPracticos(sessionStore: sessionStore)
                    } else {
                        await viewModel.finishLogin(sessionStore: sessionStore)
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(viewModel.practicosParana.isEmpty ? "Ingresar y cargar prácticos" : "Continuar")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.isLoading ||
                viewModel.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                viewModel.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (!viewModel.practicosParana.isEmpty &&
                 viewModel.selectedPilotName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )

            Spacer()
        }
        .padding()
    }
}
