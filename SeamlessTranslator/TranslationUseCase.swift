import Foundation
import SwiftUI

final class TranslationUseCase {
    // Make webRepository lazy
    private lazy var webRepository: TranslationRepositoryProtocol = {
        return TranslationRepository()
    }()
    
    private lazy var localRepository: EmbeddedTranslationRepository = {
        return EmbeddedTranslationRepository()
    }()
    
    private var currentRepository: TranslationRepositoryProtocol?

    @MainActor
    @Published var modelLoadingStatus: ModelLoadingStatus = .idle
    @AppStorage("selectedRepoID") var selectedRepoID: String = ""
    @Binding private var translationMode: TranslationMode

    init(translationMode: Binding<TranslationMode>) {
        // Initialize currentRepository based on the translation mode
        self._translationMode = translationMode
        self.currentRepository = translationMode.wrappedValue == .web ? self.webRepository : self.localRepository

        if translationMode.wrappedValue == .local && !selectedRepoID.isEmpty {
            loadLocalModel(repoID: selectedRepoID)
        }
    }

    var apiKey: String? {
        get {
            return currentRepository?.apiKey
        }
        set {
            currentRepository?.apiKey = newValue
        }
    }

    func testConnection(apiURL: String, apiPort: String?, modelName: String) async throws -> Bool {
        guard let currentRepository else { return false }
        return try await currentRepository.testConnection(apiURL: apiURL, apiPort: apiPort, modelName: modelName)
    }

    func translateText(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) async throws -> String? {
        guard let currentRepository else { throw URLError(.cannotFindHost) }
        return try await currentRepository.translateText(apiURL: apiURL, apiPort: apiPort, input: input, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, modelName: modelName)
    }

    func rephraseText(apiURL: String, apiPort: String?, input: String, modelName: String) async throws -> String? {
        guard let currentRepository else { throw URLError(.cannotFindHost) }
        return try await currentRepository.rephraseText(apiURL: apiURL, apiPort: apiPort, input: input, modelName: modelName)
    }

    func translateTextStream(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        guard let currentRepository else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: URLError(.cannotFindHost))
            }
        }
        return currentRepository.translateTextStream(apiURL: apiURL, apiPort: apiPort, input: input, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, modelName: modelName)
    }

    func rephraseTextStream(apiURL: String, apiPort: String?, input: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        guard let currentRepository else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: URLError(.cannotFindHost))
            }
        }
        return currentRepository.rephraseTextStream(apiURL: apiURL, apiPort: apiPort, input: input, modelName: modelName)
    }

    func supportsStreaming() -> Bool {
        return currentRepository?.supportsStreaming() ?? false
    }

    func saveApiKey(_ apiKey: String) {
        currentRepository?.saveApiKey(apiKey)
    }

    func loadLocalModel(repoID: String) {
        Task {
            await localRepository.loadModel(repoID: repoID)
            Task { @MainActor in
                self.modelLoadingStatus = self.localRepository.modelLoadingStatus
                if self.modelLoadingStatus == .loaded {
                    self.currentRepository = self.localRepository
                }
            }
        }
    }

    func switchMode(to mode: TranslationMode) {
        translationMode = mode
        currentRepository = mode == .web ? webRepository : localRepository
        if mode == .local && !selectedRepoID.isEmpty {
            loadLocalModel(repoID: selectedRepoID)
        }
    }

    // Forward text limit methods to the current repository
    var wordLimit: Int {
        return currentRepository?.wordLimit ?? 0
    }
    
    func limitText(_ text: String) -> String {
        return currentRepository?.limitText(text) ?? text
    }
    
    func getRemainingContext(for text: String) -> String {
        return currentRepository?.getRemainingContext(for: text) ?? "0/0"
    }
    
    func getCounterColor(for text: String) -> Color {
        return currentRepository?.getCounterColor(for: text) ?? .red
    }
}
