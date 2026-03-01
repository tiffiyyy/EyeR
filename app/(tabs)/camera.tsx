import { useFocusEffect } from "@react-navigation/native";
import { CameraView, useCameraPermissions } from "expo-camera";
import { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { Audio } from "expo-av";

import { interactionsRepository, peopleRepository } from "@/src/data/repositories";
import { type KnownEmbedding } from "@/src/domain/types";
import { recognitionPipeline } from "@/src/ml";
import { convertSpeechToText } from "@/src/ml/speechToText";

import { useTabBarVisibility } from "./TabBarVisibilityContext";

const LOOP_INTERVAL_MS = 1200;
const SUSTAINED_MS = 500;

type Bounds = { x: number; y: number; width: number; height: number };

type OverlayMatch = {
  id: string;
  name: string;
  relationship: string;
  similarity: number;
  bounds: Bounds;
};

type SustainedFace = { faceId: string; bounds: Bounds };

function CornerFrame({
  left,
  top,
  width,
  height,
}: {
  left: number;
  top: number;
  width: number;
  height: number;
}) {
  const stroke = 4;
  const cornerLen = Math.min(width, height) * 0.28;
  const baseCorner = {
    position: "absolute" as const,
    width: cornerLen,
    height: cornerLen,
    borderColor: "#5B8DEF",
    shadowColor: "#5B8DEF",
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 6,
    elevation: 4,
  };

  return (
    <View style={[styles.cornerFrameWrapper, { left, top, width, height }]} pointerEvents="none">
      <View style={[baseCorner, { top: 0, left: 0, borderTopWidth: stroke, borderLeftWidth: stroke }]} />
      <View style={[baseCorner, { top: 0, right: 0, borderTopWidth: stroke, borderRightWidth: stroke }]} />
      <View style={[baseCorner, { bottom: 0, left: 0, borderBottomWidth: stroke, borderLeftWidth: stroke }]} />
      <View style={[baseCorner, { bottom: 0, right: 0, borderBottomWidth: stroke, borderRightWidth: stroke }]} />
    </View>
  );
}

export default function CameraModeScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [audioPermission, requestAudioPermission] = Audio.usePermissions();
  const [knownEmbeddings, setKnownEmbeddings] = useState<KnownEmbedding[]>([]);
  const [overlayMatches, setOverlayMatches] = useState<OverlayMatch[]>([]);
  const [sustainedFrames, setSustainedFrames] = useState<SustainedFace[]>([]);
  const [layoutSize, setLayoutSize] = useState<{ width: number; height: number } | null>(null);
  const [isRunning, setIsRunning] = useState(true);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);

  const [showUI, setShowUI] = useState(false);
  const lockRef = useRef(false);
  const recordingRef = useRef<Audio.Recording | null>(null);
  const unseenCountRef = useRef(0);
  const activePersonIdRef = useRef<string | null>(null);
  const firstSeenAtRef = useRef<Record<string, number>>({});
  const { setHideTabBar } = useTabBarVisibility();

  // #region agent log
  useEffect(() => {
    fetch('http://127.0.0.1:7919/ingest/f09e510d-9d5b-410d-80b9-6a3747b27a58', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': 'a3f49c' }, body: JSON.stringify({ sessionId: 'a3f49c', location: 'camera.tsx:mount', message: 'Camera screen mounted', data: {}, timestamp: Date.now(), hypothesisId: 'H4' }) }).catch(() => { });
  }, []);
  // #endregion

  const refreshKnownEmbeddings = useCallback(async () => {
    const records = await peopleRepository.listKnownEmbeddings();
    setKnownEmbeddings(records);
  }, []);

  useEffect(() => {
    setHideTabBar(!showUI);
  }, [showUI, setHideTabBar]);

  useFocusEffect(
    useCallback(() => {
      refreshKnownEmbeddings().catch((error) => console.error("Failed to load known embeddings", error));
      return () => {
        setHideTabBar(false);
      };
    }, [refreshKnownEmbeddings, setHideTabBar])
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
        const now = Date.now();
        const recognized = predictions.filter(
          (entry) => !entry.match.isUnknown && entry.match.personId
        );
        const visibleMatches = recognized.map((entry) => ({
          id: entry.faceId,
          name: entry.match.personName,
          relationship: entry.match.relationship ?? "",
          similarity: entry.match.similarity,
          bounds: entry.bounds,
        }));

        const ids = new Set(recognized.map((r) => r.faceId));
        const firstSeenAt = firstSeenAtRef.current;
        Array.from(ids).forEach((faceId) => {
          if (firstSeenAt[faceId] == null) firstSeenAt[faceId] = now;
        });
        Object.keys(firstSeenAt).forEach((key) => {
          if (!ids.has(key)) delete firstSeenAt[key];
        });

        const sustained = recognized.filter(
          (entry) => now - (firstSeenAt[entry.faceId] ?? now) >= SUSTAINED_MS
        );
        setSustainedFrames(
          sustained.map((entry) => ({ faceId: entry.faceId, bounds: entry.bounds }))
        );
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
    // #region agent log
    fetch('http://127.0.0.1:7919/ingest/f09e510d-9d5b-410d-80b9-6a3747b27a58', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': 'a3f49c' }, body: JSON.stringify({ sessionId: 'a3f49c', location: 'camera.tsx:branch', message: 'Rendering branch', data: { branch: 'checking', permissionNull: true }, timestamp: Date.now(), hypothesisId: 'H2' }) }).catch(() => { });
    // #endregion
    return (
      <View style={styles.centered}>
        <Text style={styles.bodyText}>Checking permissions...</Text>
      </View>
    );
  }

  if (!permission.granted || !audioPermission.granted) {
    // #region agent log
    fetch('http://127.0.0.1:7919/ingest/f09e510d-9d5b-410d-80b9-6a3747b27a58', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': 'a3f49c' }, body: JSON.stringify({ sessionId: 'a3f49c', location: 'camera.tsx:branch', message: 'Rendering branch', data: { branch: 'denied', granted: permission.granted }, timestamp: Date.now(), hypothesisId: 'H2' }) }).catch(() => { });
    // #endregion
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

  // #region agent log
  fetch('http://127.0.0.1:7919/ingest/f09e510d-9d5b-410d-80b9-6a3747b27a58', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': 'a3f49c' }, body: JSON.stringify({ sessionId: 'a3f49c', location: 'camera.tsx:branch', message: 'Rendering branch', data: { branch: 'camera', granted: permission.granted }, timestamp: Date.now(), hypothesisId: 'H2' }) }).catch(() => { });
  // #endregion
  return (
    <View
      style={styles.container}
      onLayout={(e) => {
        const { width, height } = e.nativeEvent.layout;
        // #region agent log
        fetch('http://127.0.0.1:7919/ingest/f09e510d-9d5b-410d-80b9-6a3747b27a58', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Debug-Session-Id': 'a3f49c' }, body: JSON.stringify({ sessionId: 'a3f49c', location: 'camera.tsx:onLayout', message: 'Container layout', data: { width, height }, timestamp: Date.now(), hypothesisId: 'H1' }) }).catch(() => { });
        // #endregion
        setLayoutSize({ width, height });
      }}
    >
      <CameraView style={StyleSheet.absoluteFill} facing="back" />
      {layoutSize &&
        sustainedFrames.length > 0 && (
          <View style={StyleSheet.absoluteFill} pointerEvents="none">
            {sustainedFrames.map(({ faceId, bounds }) => (
              <CornerFrame
                key={faceId}
                left={bounds.x * layoutSize.width}
                top={bounds.y * layoutSize.height}
                width={bounds.width * layoutSize.width}
                height={bounds.height * layoutSize.height}
              />
            ))}
          </View>
        )}
      {!showUI && (
        <Pressable
          style={StyleSheet.absoluteFill}
          onPress={() => {
            setShowUI(true);
            setHideTabBar(false);
          }}
        />
      )}
      {showUI && (
        <>
          <View style={styles.headerBar}>
            <Text style={styles.headerTitle}>Camera</Text>
          </View>
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
          <Pressable
            style={styles.emptyAreaTapTarget}
            onPress={() => {
              setShowUI(false);
              setHideTabBar(true);
            }}
          />
          <View style={styles.footer}>
            <Pressable
              onPress={() => setIsRunning((value) => !value)}
              style={styles.primaryButton}
            >
              <Text style={styles.primaryButtonText}>
                {isRunning ? "Pause Recognition" : "Resume Recognition"}
              </Text>
            </Pressable>
          </View>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#000",
  },
  cornerFrameWrapper: {
    position: "absolute",
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
  headerBar: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    paddingTop: 56,
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: "rgba(0, 0, 0, 0.5)",
  },
  headerTitle: {
    color: "#fff",
    fontSize: 22,
    fontWeight: "700",
  },
  emptyAreaTapTarget: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 180,
    bottom: 100,
  },
  overlayContainer: {
    position: "absolute",
    left: 12,
    right: 12,
    top: 120,
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
