//
//  ConversationSummarizer.swift
//  GlimpseH4H
//

import Foundation

enum LLMConfig {
    static var apiKey: String {
        if let fromEnv = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !fromEnv.isEmpty {
            return fromEnv
        }
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !fromPlist.isEmpty {
            return fromPlist
        }
        return ""
    }

    static var model: String {
        if let fromEnv = ProcessInfo.processInfo.environment["OPENAI_MODEL"], !fromEnv.isEmpty {
            return fromEnv
        }
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String, !fromPlist.isEmpty {
            return fromPlist
        }
        return "gpt-4o-mini"
    }
}

actor ConversationSummarizer {
    static let shared = ConversationSummarizer()

    func summarize(transcript: String, maxLength: Int = 180) async -> String {
        let normalized = Self.normalize(transcript)
        guard !normalized.isEmpty else { return "" }
        if LLMConfig.apiKey.isEmpty {
            return Self.fallbackSummary(from: normalized, maxLength: maxLength)
        }

        do {
            let llmSummary = try await requestLLMSummary(for: normalized, maxLength: maxLength)
            if !llmSummary.isEmpty {
                return llmSummary
            }
        } catch {
            #if DEBUG
            print("[Conversation] LLM summarization failed: \(error.localizedDescription)")
            #endif
        }
        return Self.fallbackSummary(from: normalized, maxLength: maxLength)
    }

    private func requestLLMSummary(for transcript: String, maxLength: Int) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "ConversationSummarizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(LLMConfig.apiKey)", forHTTPHeaderField: "Authorization")

        let systemPrompt = "You summarize past conversations for memory recall. Return only one concise sentence in plain text."
        let userPrompt = """
        Summarize this transcript in 1 short sentence (max \(maxLength) characters).
        Focus only on the key topics discussed.

        Transcript:
        \(transcript)
        """

        let body = ChatCompletionsRequest(
            model: LLMConfig.model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2,
            maxTokens: 120
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ConversationSummarizer", code: status, userInfo: [NSLocalizedDescriptionKey: "OpenAI request failed with status \(status)"])
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.count <= maxLength {
            return text
        }
        let end = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func normalize(_ transcript: String) -> String {
        transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fallbackSummary(from normalized: String, maxLength: Int) -> String {
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

private struct ChatCompletionsRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
    var maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct ChatMessage: Codable {
    var role: String
    var content: String
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatMessage
}
