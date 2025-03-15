import SwiftUI

protocol TextLimitProtocol {
    var wordLimit: Int { get }
    func limitText(_ text: String) -> String
    func getRemainingContext(for text: String) -> String
    func getCounterColor(for text: String) -> Color
}

// Default implementation
extension TextLimitProtocol {
    func limitText(_ text: String) -> String {
        let words = text.split { $0.isWhitespace }
        if words.count > wordLimit {
            return words.prefix(wordLimit).joined(separator: " ")
        }
        return text
    }
    
    func getRemainingContext(for text: String) -> String {
        return "\(wordLimit - text.split { $0.isWhitespace }.count) words remaining"
    }
    
    func getCounterColor(for text: String) -> Color {
        return text.split { $0.isWhitespace }.count > wordLimit - 10 ? .red : .gray
    }
} 