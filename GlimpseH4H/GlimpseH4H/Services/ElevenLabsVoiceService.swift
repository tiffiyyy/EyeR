//
//  ElevenLabsVoiceService.swift
//  GlimpseH4H
//

import AVFoundation
import Foundation

enum ElevenLabsConfig {
    static var apiKey: String {
        if let fromEnv = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"], !fromEnv.isEmpty {
            return fromEnv
        }
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String, !fromPlist.isEmpty {
            return fromPlist
        }
        return ""
    }

    static var voiceId: String {
        if let fromEnv = ProcessInfo.processInfo.environment["ELEVENLABS_VOICE_ID"], !fromEnv.isEmpty {
            return fromEnv
        }
        if let fromPlist = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_VOICE_ID") as? String, !fromPlist.isEmpty {
            return fromPlist
        }
        // Default placeholder voice id. Replace via env/plist for production.
        return "EXAVITQu4vr4xnSDxMaL"
    }
}

actor ElevenLabsVoiceService {
    static let shared = ElevenLabsVoiceService()

    func synthesize(text: String) async throws -> Data {
        guard !ElevenLabsConfig.apiKey.isEmpty else {
            throw NSError(domain: "ElevenLabsVoiceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ELEVENLABS_API_KEY"])
        }
        let voiceId = ElevenLabsConfig.voiceId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ElevenLabsConfig.voiceId
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)") else {
            throw NSError(domain: "ElevenLabsVoiceService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid ElevenLabs URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ElevenLabsConfig.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ElevenLabsVoiceService", code: status, userInfo: [NSLocalizedDescriptionKey: "ElevenLabs request failed with status \(status)"])
        }
        return data
    }
}

@MainActor
final class SpeechPlaybackService: NSObject, AVAudioPlayerDelegate {
    static let shared = SpeechPlaybackService()

    private var audioPlayer: AVAudioPlayer?
    private let fallbackSynthesizer = AVSpeechSynthesizer()

    func speak(text: String) {
        Task {
            do {
                let data = try await ElevenLabsVoiceService.shared.synthesize(text: text)
                try playAudioData(data)
            } catch {
                // Fallback keeps the feature usable if network/key is unavailable.
                let utterance = AVSpeechUtterance(string: text)
                utterance.rate = 0.5
                fallbackSynthesizer.speak(utterance)
            }
        }
    }

    private func playAudioData(_ data: Data) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
