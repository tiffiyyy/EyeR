//
//  ConversationMemoryCoordinator.swift
//  GlimpseH4H
//

import Foundation

@MainActor
final class ConversationMemoryCoordinator: ObservableObject {
    static let shared = ConversationMemoryCoordinator()

    private var dataStore: DataStore?
    private let transcriber = SpeechTranscriptionService()

    private var activePersonId: UUID?
    private var sessionStartedAt: Date?
    private var permissionsGranted = false

    private init() {}

    func start(dataStore: DataStore) {
        self.dataStore = dataStore
        Task {
            permissionsGranted = await transcriber.requestPermissions()
        }
    }

    func stop() {
        if let activePersonId {
            finalizeConversation(for: activePersonId)
        }
        transcriber.stop()
        activePersonId = nil
        sessionStartedAt = nil
    }

    func handleRecognitionChange(personId: UUID?) {
        guard let dataStore else { return }

        if activePersonId == personId {
            return
        }

        if let oldPersonId = activePersonId {
            finalizeConversation(for: oldPersonId)
        }

        guard let newPersonId = personId else {
            activePersonId = nil
            sessionStartedAt = nil
            return
        }

        activePersonId = newPersonId
        sessionStartedAt = Date()

        var didSpeakRecall = false
        if let person = dataStore.people.first(where: { $0.id == newPersonId }) {
            let latestSummary = person.conversationHistory.sorted(by: { $0.endedAt > $1.endedAt }).first?.summary ?? person.conversationSummary
            if !latestSummary.isEmpty {
                let recall = "This is \(person.name). They are your \(person.relationship). You last talked about \(latestSummary)"
                SpeechPlaybackService.shared.speak(text: recall)
                didSpeakRecall = true
            }
        }

        guard permissionsGranted else { return }
        let startTranscription = { [weak self] in
            guard let self, self.activePersonId == newPersonId else { return }
            do {
                try self.transcriber.start()
            } catch {
                #if DEBUG
                print("[Conversation] failed to start speech tracking: \(error.localizedDescription)")
                #endif
            }
        }
        if didSpeakRecall {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: startTranscription)
        } else {
            startTranscription()
        }
    }

    private func finalizeConversation(for personId: UUID) {
        guard let dataStore else { return }
        let startedAt = sessionStartedAt ?? Date()
        let endedAt = Date()
        let transcript = transcriber.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriber.stop()

        guard !transcript.isEmpty else { return }
        let summary = ConversationSummarizer.summarize(transcript: transcript)
        guard !summary.isEmpty else { return }
        dataStore.appendConversation(
            personId: personId,
            transcript: transcript,
            summary: summary,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }
}
