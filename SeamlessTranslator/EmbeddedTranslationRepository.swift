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
    case loaded
    case error(String)

    static func == (lhs: ModelLoadingStatus, rhs: ModelLoadingStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
            return true
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

    func loadModel(repoID: String) async {
        modelLoadingStatus = .loading
        let manager = LLMModelManager()
        do {
            try await manager.loadModel(repoID: repoID)
            modelManager = manager
            modelLoadingStatus = .loaded
        } catch {
            modelLoadingStatus = .error(error.localizedDescription)
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
