import Foundation
import Security

enum APIEndpoint {
    case chatCompletions

    func url(apiURL: String, apiPort: String?) -> URL? {
        switch self {
        case .chatCompletions:
            if let port = apiPort, port.isEmpty == false {
                return URL(string: "\(apiURL):\(port)/chat/completions")
            } else {
                return URL(string: "\(apiURL)/chat/completions")
            }
        }
    }
}


protocol TranslationRepositoryProtocol: TextLimitProtocol {
    var apiKey: String? { get set }
    func testConnection(apiURL: String, apiPort: String?, modelName: String) async throws -> Bool
    func translateText(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) async throws -> String?
    func rephraseText(apiURL: String, apiPort: String?, input: String, modelName: String) async throws -> String?
    func saveApiKey(_ apiKey: String)
    
    // Streaming methods
    func translateTextStream(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) -> AsyncThrowingStream<String, Error>
    func rephraseTextStream(apiURL: String, apiPort: String?, input: String, modelName: String) -> AsyncThrowingStream<String, Error>
    func supportsStreaming() -> Bool
}

// Default implementation for repositories that don't support streaming
extension TranslationRepositoryProtocol {
    func translateTextStream(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    if let result = try await translateText(apiURL: apiURL, apiPort: apiPort, input: input, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, modelName: modelName) {
                        continuation.yield(result)
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
                    if let result = try await rephraseText(apiURL: apiURL, apiPort: apiPort, input: input, modelName: modelName) {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func supportsStreaming() -> Bool {
        return false
    }
}

final class TranslationRepository: TranslationRepositoryProtocol {
    @Published var apiKey: String?

    init() {
        self.apiKey = KeychainHelper.shared.getApiKey()
    }

    func testConnection(apiURL: String, apiPort: String?, modelName: String) async throws -> Bool {
        guard let url = APIEndpoint.chatCompletions.url(apiURL: apiURL, apiPort: apiPort) else {
            throw URLError(.badURL)
        }

        let parameters: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "user", "content": "what llm are you"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw error
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            } else {
                throw URLError(.badServerResponse)
            }
        } catch {
            throw error
        }
    }

    func translateText(apiURL: String, apiPort: String?, input: String, sourceLanguage: String, targetLanguage: String, modelName: String) async throws -> String? {
        guard let url = APIEndpoint.chatCompletions.url(apiURL: apiURL, apiPort: apiPort) else {
            throw URLError(.badURL)
        }

        let prompt = "Translate the following text from \(sourceLanguage) to \(targetLanguage): \(input). Only respond with the translated text."
        let parameters: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that translates text."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": wordLimit
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw error
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return nil
            }
        } catch {
            throw error
        }
    }

    func rephraseText(apiURL: String, apiPort: String?, input: String, modelName: String) async throws -> String? {
        guard let url = APIEndpoint.chatCompletions.url(apiURL: apiURL, apiPort: apiPort) else {
            throw URLError(.badURL)
        }

        let prompt = "Rephrase the following text: \(input). Only respond with the rephrased text."
        let parameters: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that rephrases text."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": wordLimit
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            throw error
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return nil
            }
        } catch {
            throw error
        }
    }

    func saveApiKey(_ apiKey: String) {
        KeychainHelper.shared.saveApiKey(apiKey)
    }

    // Text limit implementation
    var wordLimit: Int { return 500 } // Web API can handle more words
}

// Keychain helper class
class KeychainHelper {
    static let shared = KeychainHelper()

    func saveApiKey(_ apiKey: String) {
        let data = Data(apiKey.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "apiKey",
            kSecValueData: data
        ] as CFDictionary

        SecItemDelete(query)
        SecItemAdd(query, nil)
    }

    func getApiKey() -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "apiKey",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
