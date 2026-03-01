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
            if let pending = finishTrackingSession(for: activePersonId) {
                Task { [weak self] in
                    await self?.persistConversation(pending)
                }
            }
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
            if let pending = finishTrackingSession(for: oldPersonId) {
                Task { [weak self] in
                    await self?.persistConversation(pending)
                }
            }
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

    private func finishTrackingSession(for personId: UUID) -> PendingConversation? {
        let startedAt = sessionStartedAt ?? Date()
        let endedAt = Date()
        let transcript = transcriber.currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriber.stop()
        sessionStartedAt = nil

        guard !transcript.isEmpty else { return nil }
        return PendingConversation(
            personId: personId,
            startedAt: startedAt,
            endedAt: endedAt,
            transcript: transcript
        )
    }

    private func persistConversation(_ pending: PendingConversation) async {
        guard let dataStore else { return }
        let summary = await ConversationSummarizer.shared.summarize(transcript: pending.transcript)
        guard !summary.isEmpty else { return }
        dataStore.appendConversation(
            personId: pending.personId,
            transcript: pending.transcript,
            summary: summary,
            startedAt: pending.startedAt,
            endedAt: pending.endedAt
        )
    }
}

private struct PendingConversation {
    let personId: UUID
    let startedAt: Date
    let endedAt: Date
    let transcript: String
}
