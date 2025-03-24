//
//  EmbeddedTranslationRepository.swift
//  SeamlessTranslator
//
//  Created by Harley Pham on 9/3/25.
//

import Foundation
import LLMLib

enum ModelLoadingStatus: Equatable {
    case idle
    case loading
    case downloading(progress: Double)
    case loaded
    case error(String)
    case cancelled

    static func == (lhs: ModelLoadingStatus, rhs: ModelLoadingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded), (.cancelled, .cancelled):
            return true
        case (.downloading(let lhsProgress), .downloading(let rhsProgress)):
            return abs(lhsProgress - rhsProgress) < 0.01 // Consider close progress values as equal
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

final class EmbeddedTranslationRepository: TranslationRepositoryProtocol {
    @Published var apiKey: String?
    @Published var modelLoadingStatus: ModelLoadingStatus = .idle

    var modelManager: LLMModelManager?
    private var currentLoadingManager: LLMModelManager?
    private var loadingTask: Task<Void, Error>?

    // Cancel any ongoing model loading or downloading
    func cancelModelLoading() {
        // Cancel the loading task
        loadingTask?.cancel()
        loadingTask = nil
        
        // Cancel the model download
        currentLoadingManager?.cancelDownload()
        currentLoadingManager = nil
        
        // Update UI status
        Task { @MainActor in
            if case .downloading = modelLoadingStatus  {
                modelLoadingStatus = .cancelled
            }
            else if modelLoadingStatus == .loading {
                modelLoadingStatus = .cancelled
            }
        }
    }

    func loadModel(repoID: String) async {
        // Cancel any previous loading task
        cancelModelLoading()
        
        // Set status to loading and create a new manager
        modelLoadingStatus = .loading
        let manager = LLMModelManager()
        currentLoadingManager = manager
        
        // Create a loading task that can be cancelled
        loadingTask = Task.detached { [weak self] in
            do {
                // Use a local progress handler
                let modelPrefix = repoID.split(separator: "/").last?.replacingOccurrences(of: "-CoreML", with: "")
                try await manager.loadModel(repoID: repoID, localModelPrefix: modelPrefix, progressHandler: { progress in
                    Task { @MainActor in
                        // Update progress only if we're still loading
                        if let self = self, 
                           self.currentLoadingManager === manager {
                            self.modelLoadingStatus = .downloading(progress: progress)
                        }
                    }
                })
                
                // Success - update state on main actor
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if self.currentLoadingManager === manager {
                        self.modelManager = manager
                        self.modelLoadingStatus = .loaded
                        self.currentLoadingManager = nil
                    }
                }
            } catch {
                // Handle errors on main actor
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    // Only update status if this is the current manager
                    if self.currentLoadingManager === manager {
                        if let error = error as? LLMModelManagerError, error == .cancelled {
                            self.modelLoadingStatus = .cancelled
                        } else if Task.isCancelled {
                            self.modelLoadingStatus = .cancelled
                        } else {
                            self.modelLoadingStatus = .error(error.localizedDescription)
                        }
                        self.currentLoadingManager = nil
                    }
                }
            }
        }
        
        // Set up a task to monitor for cancellation
        Task {
            // Wait a bit to check for early cancellation (e.g. user changed model or switched mode right away)
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled || loadingTask?.isCancelled == true {
                cancelModelLoading()
            }
        }
    }

    func testConnection(apiURL: String, apiPort: String?, modelName: String) async throws -> Bool {
        return modelManager != nil
    }

    func translateText(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) async throws -> String? {
        guard let manager = modelManager else {
            throw URLError(.cannotFindHost)
        }
        let message = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        You are a helpful assistant. <|eot_id|><|start_header_id|>user<|end_header_id|>You must translate the following text from \(sourceLanguage) to \(targetLanguage), only respond with the translated text:"\(input)"<|eot_id|><|start_header_id|>assistant<|end_header_id|>
        """
        return try await manager.generateText(inputText: message, maxNewTokens: 500)
    }

    func rephraseText(apiURL: String, apiPort: String?, input: String, modelName: String) async throws -> String? {
        guard let manager = modelManager else {
            throw URLError(.cannotFindHost)
        }

        let message = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>You are a helpful assistant that rephrases text. <|eot_id|><|start_header_id|>user<|end_header_id|>Rephrase the following text, only respond with the rephrased text:"\(input)"<|eot_id|><|start_header_id|>assistant<|end_header_id|>
        """
        return try await manager.generateText(inputText: message, maxNewTokens: 500)
    }
    
    // Implement streaming methods
    func translateTextStream(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let manager = modelManager else {
                        throw URLError(.cannotFindHost)
                    }
                    
                    let message = """
                    <|begin_of_text|><|start_header_id|>system<|end_header_id|>You are a helpful assistant.<|eot_id|><|start_header_id|>user<|end_header_id|>You must translate the following text from \(sourceLanguage) to \(targetLanguage), must only respond with the translated text, do not adding anything else.
                    "\(input)"<|eot_id|>
                    <|start_header_id|>assistant<|end_header_id|>
                    
                    """
                    
                    let textStream = manager.generateTextStream(inputText: message, maxNewTokens: 500)
                    for try await textChunk in textStream {
                        continuation.yield(textChunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func rephraseTextStream(apiURL: String, apiPort: String?, input: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let manager = modelManager else {
                        throw URLError(.cannotFindHost)
                    }
                    
                    let message = """
                    <|begin_of_text|><|start_header_id|>system<|end_header_id|>You are a helpful assistant that rephrases text. <|eot_id|><|start_header_id|>user<|end_header_id|>Rephrase the following text, only respond with the rephrased text. Do not adding anything else.
                    "\(input)"<|eot_id|>
                    <|start_header_id|>assistant<|end_header_id|>
                    
                    """

                    let textStream = manager.generateTextStream(inputText: message, maxNewTokens: 500)
                    for try await textChunk in textStream {
                        continuation.yield(textChunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func supportsStreaming() -> Bool {
        return modelManager != nil
    }

    func saveApiKey(_ apiKey: String) {
        // No need to save API key for local model
    }

    // Text limit implementation
    var wordLimit: Int { return 180 } // Local model has a smaller limit
}
