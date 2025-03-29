import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        Form {
            // Quick Paste Settings Section
            Section(header: Text("Quick Paste Settings")) {
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("Enable Quick Paste (⌘+⇧+P)", isOn: $viewModel.quickPasteEnabled)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Text("How to use:")
                        .font(.subheadline)
                        .padding(.top, 5)
                    
                    Text("1. Copy text with ⌘+C in any application")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("2. Press ⌘+⇧+P to open translator with that text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.quickPasteEnabled {
                        Divider()
                            .padding(.vertical, 5)
                        
                        Toggle("Auto-process after paste", isOn: $viewModel.autoProcessAfterPaste)
                            .toggleStyle(SwitchToggleStyle())
                            .padding(.bottom, 5)
                        
                        if viewModel.autoProcessAfterPaste {
                            Picker("Action", selection: $viewModel.quickPasteAction) {
                                Text("Translate").tag(QuickPasteAction.translate)
                                Text("Rephrase").tag(QuickPasteAction.rephrase)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            .padding()
            
            // API Configuration Section
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
//                        Text("andmev/Llama-3.2-3B-Instruct-CoreML").tag("andmev/Llama-3.2-3B-Instruct-CoreML")
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
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Loading model...")
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Button("Cancel") {
                                viewModel.cancelModelLoading()
                            }
                            .padding(.top, 5)
                        }
                    case .downloading(let progress):
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Downloading model: \(Int(progress * 100))%")
                            ProgressView(value: progress)
                                .progressViewStyle(LinearProgressViewStyle())
                            Button("Cancel Download") {
                                viewModel.cancelModelLoading()
                            }
                            .padding(.top, 5)
                        }
                    case .cancelled:
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Download cancelled")
                                .foregroundColor(.orange)
                            Button("Try Again") {
                                if !viewModel.selectedRepoID.isEmpty {
                                    viewModel.loadLocalModel(repoID: viewModel.selectedRepoID)
                                }
                            }
                            .padding(.top, 5)
                        }
                    case .loaded:
                        Text("Model loaded successfully.")
                            .foregroundColor(.green)
                    case .error(let message):
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Error loading model: \(message)")
                                .foregroundColor(.red)
                            Button("Try Again") {
                                if !viewModel.selectedRepoID.isEmpty {
                                    viewModel.loadLocalModel(repoID: viewModel.selectedRepoID)
                                }
                            }
                            .padding(.top, 5)
                        }
                    }
                }
            }
            .padding()
            Spacer()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 300, maxHeight: .infinity)
        .animation(.default, value: viewModel.connectionStatus)
        .animation(.default, value: viewModel.modelLoadingStatus)
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
