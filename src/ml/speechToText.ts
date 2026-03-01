export async function convertSpeechToText(audioUri: string): Promise<string> {
    const formData = new FormData();
    formData.append("file", {
        uri: audioUri,
        type: "audio/m4a", // iOS/Android default high quality recording type
        name: "audio.m4a",
    } as any);

    formData.append("model_id", "scribe_v2");
    formData.append("tag_audio_events", "true");
    formData.append("language_code", "eng");

    const apiKey = process.env.EXPO_PUBLIC_ELEVENLABS_API_KEY;
    if (!apiKey) {
        throw new Error("Missing EXPO_PUBLIC_ELEVENLABS_API_KEY");
    }

    const response = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
        method: "POST",
        headers: {
            "xi-api-key": apiKey,
        },
        body: formData,
    });

    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`ElevenLabs STT error: ${response.status} - ${errorText}`);
    }

    const data = await response.json();
    return data.text;
}
