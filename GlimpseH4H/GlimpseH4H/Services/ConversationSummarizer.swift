//
//  ConversationSummarizer.swift
//  GlimpseH4H
//

import Foundation

enum ConversationSummarizer {
    static func summarize(transcript: String, maxLength: Int = 180) -> String {
        let normalized = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let separators = CharacterSet(charactersIn: ".!?")
        let sentences = normalized
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let summaryBase = sentences.prefix(2).joined(separator: ". ")
        let candidate = summaryBase.isEmpty ? normalized : "\(summaryBase)."
        if candidate.count <= maxLength {
            return candidate
        }
        let end = candidate.index(candidate.startIndex, offsetBy: maxLength)
        return String(candidate[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}
