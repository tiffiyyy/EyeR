import { useFocusEffect } from "@react-navigation/native";
import { CameraView, useCameraPermissions } from "expo-camera";
import { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { Audio } from "expo-av";

import { interactionsRepository, peopleRepository } from "@/src/data/repositories";
import { type KnownEmbedding } from "@/src/domain/types";
import { recognitionPipeline } from "@/src/ml";
import { convertSpeechToText } from "@/src/ml/speechToText";

const LOOP_INTERVAL_MS = 1200;

type OverlayMatch = {
  id: string;
  name: string;
  relationship: string;
  similarity: number;
};

export default function CameraModeScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [audioPermission, requestAudioPermission] = Audio.usePermissions();
  const [knownEmbeddings, setKnownEmbeddings] = useState<KnownEmbedding[]>([]);
  const [overlayMatches, setOverlayMatches] = useState<OverlayMatch[]>([]);
  const [isRunning, setIsRunning] = useState(true);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);

  const lockRef = useRef(false);
  const recordingRef = useRef<Audio.Recording | null>(null);
  const unseenCountRef = useRef(0);
  const activePersonIdRef = useRef<string | null>(null);

  const refreshKnownEmbeddings = useCallback(async () => {
    const records = await peopleRepository.listKnownEmbeddings();
    setKnownEmbeddings(records);
  }, []);

  useFocusEffect(
    useCallback(() => {
      refreshKnownEmbeddings().catch((error) => console.error("Failed to load known embeddings", error));
    }, [refreshKnownEmbeddings])
  );

  useEffect(() => {
    if (!permission?.granted || !isRunning) {
      return;
    }

    const timer = setInterval(async () => {
      if (lockRef.current) {
        return;
      }
      lockRef.current = true;

      try {
        const frame = {
          token: `frame_${Date.now()}`,
          capturedAt: Date.now(),
        };
        const predictions = await recognitionPipeline.run(frame, knownEmbeddings);
        const visibleMatches = predictions
          .filter((entry) => !entry.match.isUnknown && entry.match.personId)
          .map((entry) => ({
            id: entry.faceId,
            name: entry.match.personName,
            relationship: entry.match.relationship ?? "",
            similarity: entry.match.similarity,
          }));

        setOverlayMatches(visibleMatches);

        if (visibleMatches.length > 0) {
          unseenCountRef.current = 0;
          const primaryPersonId = predictions.find((p) => !p.match.isUnknown && p.match.personId)?.match.personId;

          if (primaryPersonId && !recordingRef.current && audioPermission?.granted) {
            activePersonIdRef.current = primaryPersonId;
            try {
              await Audio.setAudioModeAsync({
                allowsRecordingIOS: true,
                playsInSilentModeIOS: true,
              });
              const { recording: newRecording } = await Audio.Recording.createAsync(
                Audio.RecordingOptionsPresets.HIGH_QUALITY
              );
              recordingRef.current = newRecording;
              setRecording(newRecording);
            } catch (err) {
              console.error("Failed to start recording", err);
            }
          }
        } else {
          unseenCountRef.current += 1;
          if (unseenCountRef.current > 2 && recordingRef.current) {
            const currentRecording = recordingRef.current;
            recordingRef.current = null;
            setRecording(null);

            try {
              await currentRecording.stopAndUnloadAsync();
              const uri = currentRecording.getURI();
              if (uri && activePersonIdRef.current) {
                const personId = activePersonIdRef.current;
                activePersonIdRef.current = null;

                convertSpeechToText(uri).then(async (transcript) => {
                  if (transcript.trim()) {
                    await interactionsRepository.create({
                      personId: personId,
                      transcript: transcript,
                    });
                    console.log(`Saved interaction for ${personId}: ${transcript}`);
                  }
                }).catch(err => console.error("STT error", err));
              }
            } catch (err) {
              console.error("Failed to stop recording", err);
            }
          }
        }
      } catch (error) {
        console.error("Recognition loop failed", error);
      } finally {
        lockRef.current = false;
      }
    }, LOOP_INTERVAL_MS);

    return () => clearInterval(timer);
  }, [isRunning, knownEmbeddings, permission?.granted]);

  if (!permission || !audioPermission) {
    return (
      <View style={styles.centered}>
        <Text style={styles.bodyText}>Checking permissions...</Text>
      </View>
    );
  }

  if (!permission.granted || !audioPermission.granted) {
    return (
      <View style={styles.centered}>
        <Text style={styles.titleText}>Camera & Audio permission required</Text>
        <Text style={styles.bodyText}>
          EyeRemember processes camera and audio data locally or uses secure APIs and does not upload raw images.
        </Text>
        <Pressable onPress={() => { requestPermission(); requestAudioPermission(); }} style={styles.primaryButton}>
          <Text style={styles.primaryButtonText}>Allow Permissions</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView style={StyleSheet.absoluteFill} facing="back" />
      <View style={styles.overlayContainer}>
        {overlayMatches.map((entry) => (
          <View key={entry.id} style={styles.overlayCard}>
            <Text style={styles.overlayName}>{entry.name}</Text>
            <Text style={styles.overlayMeta}>
              {entry.relationship} - {Math.round(entry.similarity * 100)}%
            </Text>
          </View>
        ))}
      </View>
      {recording && (
        <View style={styles.recordingIndicator}>
          <View style={styles.recordingDot} />
          <Text style={styles.recordingText}>Listening</Text>
        </View>
      )}
      <View style={styles.footer}>
        <Pressable onPress={() => setIsRunning((value) => !value)} style={styles.primaryButton}>
          <Text style={styles.primaryButtonText}>{isRunning ? "Pause Recognition" : "Resume Recognition"}</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#000",
  },
  centered: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#0f172a",
    padding: 20,
    gap: 12,
  },
  titleText: {
    color: "#fff",
    fontSize: 28,
    fontWeight: "800",
    textAlign: "center",
  },
  bodyText: {
    color: "#e2e8f0",
    fontSize: 18,
    textAlign: "center",
    lineHeight: 24,
  },
  overlayContainer: {
    position: "absolute",
    left: 12,
    right: 12,
    top: 12,
    gap: 10,
  },
  overlayCard: {
    backgroundColor: "rgba(15, 23, 42, 0.92)",
    borderWidth: 2,
    borderColor: "#f8fafc",
    borderRadius: 12,
    padding: 12,
  },
  overlayName: {
    color: "#fff",
    fontSize: 26,
    fontWeight: "800",
  },
  overlayMeta: {
    color: "#cbd5e1",
    fontSize: 18,
    fontWeight: "600",
  },
  footer: {
    position: "absolute",
    bottom: 28,
    left: 16,
    right: 16,
  },
  primaryButton: {
    backgroundColor: "#1d4ed8",
    borderRadius: 12,
    paddingVertical: 14,
    paddingHorizontal: 16,
    alignItems: "center",
  },
  primaryButtonText: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "700",
  },
  recordingIndicator: {
    position: "absolute",
    top: 60,
    right: 20,
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "rgba(0,0,0,0.6)",
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    gap: 8,
  },
  recordingDot: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: "#ef4444",
  },
  recordingText: {
    color: "#fff",
    fontWeight: "600",
  },
});
