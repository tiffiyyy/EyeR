import { useFocusEffect } from "@react-navigation/native";
import { CameraView, useCameraPermissions } from "expo-camera";
import { useCallback, useEffect, useRef, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { peopleRepository } from "@/src/data/repositories";
import { type KnownEmbedding } from "@/src/domain/types";
import { recognitionPipeline } from "@/src/ml";

const LOOP_INTERVAL_MS = 1200;

type OverlayMatch = {
  id: string;
  name: string;
  relationship: string;
  similarity: number;
};

export default function CameraModeScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [knownEmbeddings, setKnownEmbeddings] = useState<KnownEmbedding[]>([]);
  const [overlayMatches, setOverlayMatches] = useState<OverlayMatch[]>([]);
  const [isRunning, setIsRunning] = useState(true);
  const lockRef = useRef(false);
  const cameraRef = useRef<CameraView>(null);

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
        if (!cameraRef.current) {
          return;
        }

        const photo = await cameraRef.current.takePictureAsync({
          base64: false,
          quality: 0.1,
          skipProcessing: true,
        });

        if (!photo || !photo.uri) {
          return;
        }

        const frame = {
          token: photo.uri,
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
      } catch (error) {
        console.error("Recognition loop failed", error);
      } finally {
        lockRef.current = false;
      }
    }, LOOP_INTERVAL_MS);

    return () => clearInterval(timer);
  }, [isRunning, knownEmbeddings, permission?.granted]);

  if (!permission) {
    return (
      <View style={styles.centered}>
        <Text style={styles.bodyText}>Checking camera permissions...</Text>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={styles.centered}>
        <Text style={styles.titleText}>Camera permission required</Text>
        <Text style={styles.bodyText}>
          EyeRemember processes camera data locally on-device and does not upload images.
        </Text>
        <Pressable onPress={requestPermission} style={styles.primaryButton}>
          <Text style={styles.primaryButtonText}>Allow Camera</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView style={StyleSheet.absoluteFill} facing="front" ref={cameraRef} />
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
});
