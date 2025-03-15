import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        Form {
            Section(header: Text("API Configuration")) {
                Toggle(isOn: Binding(
                    get: { viewModel.translationMode == .local },
                    set: { viewModel.switchMode(to: $0 ? .local : .web) }
                )) {
                    Text("Use Local Model")
                }
                .toggleStyle(SwitchToggleStyle())

                if viewModel.translationMode == .web {
                    TextField("API URL", text: $viewModel.apiURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("API Port", text: $viewModel.apiPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Model Name", text: $viewModel.modelName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    SecureField("API Key", text: Binding.from($viewModel.apiKey, replacingNilWith: ""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Save API Key") {
                        viewModel.saveApiKey()
                    }
                    Button("Test Connection") {
                        withAnimation {
                            viewModel.testConnection()
                        }
                    }
                    if let connectionStatus = viewModel.connectionStatus {
                        Text(connectionStatus)
                            .foregroundColor(connectionStatus == "Succeeded" ? .green : .red)
                            .transition(.opacity)
                    }
                } else {
                    Picker("Local Model", selection: $viewModel.selectedRepoID) {
                        Text("smpanaro/Llama-3.2-1B-Instruct-CoreML").tag("smpanaro/Llama-3.2-1B-Instruct-CoreML")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: viewModel.selectedRepoID) { newRepoID in
                        if !newRepoID.isEmpty {
                            viewModel.loadLocalModel(repoID: newRepoID)
                        }
                    }

                    switch viewModel.modelLoadingStatus {
                    case .idle:
                        Text("Select a model to load.")
                    case .loading:
                        Text("Loading model...")
                    case .loaded:
                        Text("Model loaded successfully.")
                    case .error(let message):
                        Text("Error loading model: \(message)")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            Spacer()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 300, maxHeight: .infinity)
        .animation(.default, value: viewModel.connectionStatus)
    }
}

extension Binding where Value == String? {
    static func from(_ source: Binding<String?>, replacingNilWith nilReplacement: String) -> Binding<String> {
        Binding<String>(
            get: { source.wrappedValue ?? nilReplacement },
            set: { newValue in
                source.wrappedValue = newValue.isEmpty ? nil : newValue
            }
        )
    }
}
