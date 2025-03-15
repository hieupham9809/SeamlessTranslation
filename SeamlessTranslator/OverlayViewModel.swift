import SwiftUI
import Combine

enum TranslationMode: String {
    case web = "Web API"
    case local = "Local Model"
}

final class OverlayViewModel: ObservableObject {
    @Published var inputText: String = "" {
        didSet {
            guard inputText != oldValue else { return }
            limitInputText()
        }
    }
    @Published var outputText: String = ""
    @AppStorage("sourceLanguage") var sourceLanguage: String = "English"
    @AppStorage("targetLanguage") var targetLanguage: String = "Vietnamese"
    @Published var selectedTab: Int = 0
    @AppStorage("apiURL") var apiURL: String = ""
    @AppStorage("apiPort") var apiPort: String = ""
    @AppStorage("modelName") var modelName: String = ""
    @AppStorage("translationMode") var translationMode: TranslationMode = .web
    @Published var connectionStatus: String?
    @Published var statusMessage: String?
    @MainActor
    @Published var modelLoadingStatus: ModelLoadingStatus = .idle
    @AppStorage("selectedRepoID") var selectedRepoID: String = ""
    @Published var isStreaming: Bool = false

    let languages = LanguageOptions.languages

    private lazy var translationUseCase: TranslationUseCase = {
        return TranslationUseCase(translationMode: $translationMode)
    }()

    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?

    @MainActor
    init() {
        self.apiKey = translationUseCase.apiKey
        self.modelLoadingStatus = translationUseCase.modelLoadingStatus

        translationUseCase.$modelLoadingStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.modelLoadingStatus, on: self)
            .store(in: &cancellables)
    }

    var apiKey: String? {
        get {
            return translationUseCase.apiKey
        }
        set {
            translationUseCase.apiKey = newValue
        }
    }
//    {
//        didSet {
//            translationUseCase.apiKey = apiKey
//        }
//    }

    @MainActor
    var isLocalModelLoading: Bool {
        return translationMode == .local && 
               (modelLoadingStatus == .loading || modelLoadingStatus == .idle)
    }

    @MainActor
    var modelLoadingStatusText: String {
        switch modelLoadingStatus {
        case .idle:
            return "Model not loaded"
        case .loading:
            return "Loading model..."
        case .loaded:
            return "Model loaded successfully"
        case .error(let message):
            return "Error loading model: \(message)"
        }
    }

    private func limitInputText() {
        inputText = translationUseCase.limitText(inputText)
    }

    // Computed properties for the counter now use the use case
    var remainingContext: String {
        return translationUseCase.getRemainingContext(for: inputText)
    }

    var counterColor: Color {
        return translationUseCase.getCounterColor(for: inputText)
    }

    func translateText() {
        // Cancel any ongoing task
        currentTask?.cancel()
        
        // Clear output text
        outputText = ""
        
        if translationUseCase.supportsStreaming() {
            translateWithStreaming()
        } else {
            translateWithoutStreaming()
        }
    }
    
    private func translateWithStreaming() {
        isStreaming = true
        statusMessage = "Translating..."
        
        currentTask = Task {
            do {
                let textStream = translationUseCase.translateTextStream(
                    apiURL: apiURL,
                    apiPort: apiPort,
                    input: inputText,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    modelName: modelName
                )
                
                for try await textChunk in textStream {
                    if Task.isCancelled { break }
                    
                    await MainActor.run {
                        self.outputText += textChunk
                        self.statusMessage = nil
                    }
                }
                
                await MainActor.run {
                    self.isStreaming = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.statusMessage = "Translation failed: \(error.localizedDescription)"
                        self.isStreaming = false
                    }
                }
            }
        }
    }
    
    private func translateWithoutStreaming() {
        Task {
            do {
                await MainActor.run { self.statusMessage = "Translating..." }
                if let translatedText = try await translationUseCase.translateText(apiURL: apiURL, apiPort: apiPort, input: inputText, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, modelName: modelName) {
                    Task { @MainActor in
                        self.outputText = translatedText
                        self.statusMessage = nil
                    }
                }
            } catch {
                Task { @MainActor in
                    self.statusMessage = "Translation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func rephraseText() {
        // Cancel any ongoing task
        currentTask?.cancel()
        
        // Clear output text
        outputText = ""
        
        if translationUseCase.supportsStreaming() {
            rephraseWithStreaming()
        } else {
            rephraseWithoutStreaming()
        }
    }
    
    private func rephraseWithStreaming() {
        isStreaming = true
        statusMessage = "Rephrasing..."
        
        currentTask = Task {
            do {
                let textStream = translationUseCase.rephraseTextStream(
                    apiURL: apiURL,
                    apiPort: apiPort,
                    input: inputText,
                    modelName: modelName
                )
                
                for try await textChunk in textStream {
                    if Task.isCancelled { break }
                    
                    await MainActor.run {
                        self.outputText += textChunk
                        self.statusMessage = nil
                    }
                }
                
                await MainActor.run {
                    self.isStreaming = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.statusMessage = "Rephrasing failed: \(error.localizedDescription)"
                        self.isStreaming = false
                    }
                }
            }
        }
    }
    
    private func rephraseWithoutStreaming() {
        Task {
            do {
                self.statusMessage = "Rephrasing..."
                if let rephrasedText = try await translationUseCase.rephraseText(apiURL: apiURL, apiPort: apiPort, input: inputText, modelName: modelName) {
                    Task { @MainActor in
                        self.outputText = rephrasedText
                        self.statusMessage = nil
                    }
                }
            } catch {
                Task { @MainActor in
                    self.statusMessage = "Rephrasing failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func cancelCurrentOperation() {
        currentTask?.cancel()
        currentTask = nil
        
        Task { @MainActor in
            self.isStreaming = false
            self.statusMessage = "Operation cancelled"
        }
    }

    func testConnection() {
        Task {
            do {
                let success = try await translationUseCase.testConnection(apiURL: apiURL, apiPort: apiPort, modelName: modelName)
                Task { @MainActor in
                    self.connectionStatus = success ? "Succeeded" : "Failed"
                }
            } catch {
                Task { @MainActor in
                    self.connectionStatus = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func saveApiKey() {
        if let apiKey = apiKey {
            translationUseCase.saveApiKey(apiKey)
        }
    }

    func loadLocalModel(repoID: String) {
        translationUseCase.loadLocalModel(repoID: repoID)
    }

    func switchMode(to mode: TranslationMode) {
        translationUseCase.switchMode(to: mode)
        if mode == .local && !selectedRepoID.isEmpty {
            loadLocalModel(repoID: selectedRepoID)
        }
    }
}
