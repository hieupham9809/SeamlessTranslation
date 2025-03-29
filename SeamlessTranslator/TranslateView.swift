import SwiftUI

struct TranslateView: View {
    @ObservedObject var viewModel: OverlayViewModel
    @State private var showCopyNotification = false
    @State private var translatedTextHeight: CGFloat = 0
    @State private var showQuickPasteNotification = false
    
    // Add a constant ID for the bottom content
    private let bottomID = "BOTTOM_ID"

    @MainActor
    var body: some View {
        VStack {
            TextEditor(text: $viewModel.inputText)
                .font(.system(size: 20, weight: .semibold))
                .frame(height: 150)
                .border(Color.gray, width: 1)
                .padding([.leading, .trailing, .top])
                .cornerRadius(8)
                .shadow(radius: 5)
                .disabled(viewModel.isStreaming || viewModel.isLocalModelLoading)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("QuickPasteEvent"))) { notification in
                    if let text = notification.userInfo?["text"] as? String {
                        viewModel.handleQuickPaste(text: text)
                        showQuickPasteNotification = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showQuickPasteNotification = false
                        }
                    }
                }

            // Word counter using properties from the view model
            HStack {
                Spacer()
                Text(viewModel.remainingContext)
                    .font(.caption)
                    .foregroundColor(viewModel.counterColor)
            }
            .padding(.trailing)

            HStack {
                if viewModel.isStreaming {
                    Button("Cancel") {
                        viewModel.cancelCurrentOperation()
                    }
                    .buttonStyle(CancelButtonStyle())
                } else if viewModel.isLocalModelLoading {
                    // Show loading indicator when model is loading
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading model...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("Translate") {
                        withAnimation {
                            viewModel.translateText()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLocalModelLoading)
                    
                    Button("Rephrase") {
                        withAnimation {
                            viewModel.rephraseText()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLocalModelLoading)
                }
            }
            .padding([.leading, .trailing])

            HStack {
                Picker("From:", selection: $viewModel.sourceLanguage) {
                    ForEach(viewModel.languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(viewModel.isStreaming || viewModel.isLocalModelLoading)

                Picker("To:", selection: $viewModel.targetLanguage) {
                    ForEach(viewModel.languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .disabled(viewModel.isStreaming || viewModel.isLocalModelLoading)
            }
            .padding([.leading, .trailing])

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        // Make output text selectable
                        Text(viewModel.outputText)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .animation(.easeInOut(duration: 0.1), value: viewModel.outputText)
                            .contextMenu {
                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(viewModel.outputText, forType: .string)
                                    showCopyNotification = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showCopyNotification = false
                                    }
                                }
                            }
                        
                        if viewModel.isStreaming {
                            HStack {
                                Text("Generating")
                                    .foregroundColor(.secondary)
                                TypingIndicator()
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            .id(bottomID) // Add ID to the bottom element
                        } else {
                            // Add an empty spacer with the bottom ID when not streaming
                            Color.clear
                                .frame(height: 1)
                                .id(bottomID)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.01)) // Invisible background for tap gesture
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .shadow(radius: 5)
                }
                .onChange(of: viewModel.outputText) { _ in
                    // Scroll to the bottom ID
                    DispatchQueue.main.async {
                        withAnimation {
                            scrollProxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(height: min(400, max(100, translatedTextHeight)))
            .padding()

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .foregroundColor(statusMessage.contains("failed") ? .red : .blue)
                    .padding()
            } else if viewModel.isLocalModelLoading {
                // Show model loading status
                Text(viewModel.modelLoadingStatusText)
                    .foregroundColor(.blue)
                    .padding()
            }

            HStack(spacing: 16) {
                if showCopyNotification {
                    Text("Content copied to clipboard!")
                        .foregroundColor(.green)
                        .padding(.vertical, 4)
                        .transition(.opacity)
                }
                
                if showQuickPasteNotification {
                    let action = viewModel.autoProcessAfterPaste ? 
                        (viewModel.quickPasteAction == .translate ? " - Auto-translating..." : " - Auto-rephrasing...") : 
                        ""
                    Text("Quick Paste activated! (⌘+⇧+P)\(action)")
                        .foregroundColor(.green)
                        .padding(.vertical, 4)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: showCopyNotification)
            .animation(.default, value: showQuickPasteNotification)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 400)
        .animation(.default, value: viewModel.outputText)
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 5, height: 5)
                    .opacity(dotCount >= index + 1 ? 1 : 0.3)
            }
        }
        .onAppear {
            let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
            _ = timer.sink { _ in
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct CancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

extension View {
    func size(_ handler: @escaping (CGSize) -> Void) -> some View {
        background(GeometryReader { proxy in
            DispatchQueue.main.async {
                handler(proxy.size)
            }
            return Color.clear
        })
    }
}
