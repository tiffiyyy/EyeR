import { Audio } from "expo-av";
import { useFocusEffect } from "@react-navigation/native";
import { useCallback, useState } from "react";
import { FlatList, Pressable, StyleSheet, Text, TextInput, View } from "react-native";

import { memoriesRepository } from "@/src/data/repositories";
import { extractTopicsFromText } from "@/src/domain/topicExtraction";
import { type MemoryRecord } from "@/src/domain/types";

export default function MemoriesScreen() {
  const [memories, setMemories] = useState<MemoryRecord[]>([]);
  const [query, setQuery] = useState("");
  const [topicInput, setTopicInput] = useState("");

  const loadMemories = useCallback(async () => {
    const records = query.trim()
      ? await memoriesRepository.search(query.trim())
      : await memoriesRepository.list();
    setMemories(records);
  }, [query]);

  useFocusEffect(
    useCallback(() => {
      loadMemories().catch((error) => console.error("Failed to load memories", error));
    }, [loadMemories])
  );

  const addMockMemory = async () => {
    await Audio.requestPermissionsAsync();
    // TODO(real-nlp): Replace this with speech-to-text + semantic topic extraction.
    const topics = extractTopicsFromText(topicInput);
    if (topics.length === 0) {
      return;
    }
    await memoriesRepository.create({
      topics,
      summary: `Conversation about ${topics.slice(0, 3).join(", ")}`,
    });
    setTopicInput("");
    await loadMemories();
  };

  return (
    <View style={styles.container}>
      <Text style={styles.helper}>
        Audio memory is local-first. This version stores placeholder topics for later review.
      </Text>

      <TextInput
        value={topicInput}
        onChangeText={setTopicInput}
        placeholder="Enter conversation text or topics"
        placeholderTextColor="#94a3b8"
        style={styles.input}
      />
      <Pressable style={styles.primaryButton} onPress={addMockMemory}>
        <Text style={styles.primaryButtonText}>Capture Memory (Mock)</Text>
      </Pressable>

      <TextInput
        value={query}
        onChangeText={setQuery}
        onSubmitEditing={() => loadMemories()}
        placeholder="Search topics"
        placeholderTextColor="#94a3b8"
        style={styles.input}
      />
      <Pressable style={styles.secondaryButton} onPress={loadMemories}>
        <Text style={styles.secondaryButtonText}>Search</Text>
      </Pressable>

      <FlatList
        data={memories}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={<Text style={styles.empty}>No memories yet.</Text>}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <Text style={styles.cardTime}>{new Date(item.timestamp).toLocaleString()}</Text>
            <Text style={styles.cardTopics}>{item.topics.join(", ")}</Text>
            {item.summary ? <Text style={styles.cardSummary}>{item.summary}</Text> : null}
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#020617",
    padding: 14,
  },
  helper: {
    color: "#cbd5e1",
    fontSize: 16,
    lineHeight: 22,
    marginBottom: 10,
  },
  input: {
    backgroundColor: "#0f172a",
    color: "#f8fafc",
    borderColor: "#334155",
    borderWidth: 1,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 17,
    marginBottom: 8,
  },
  primaryButton: {
    backgroundColor: "#1d4ed8",
    borderRadius: 10,
    paddingVertical: 12,
    alignItems: "center",
    marginBottom: 12,
  },
  primaryButtonText: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "700",
  },
  secondaryButton: {
    backgroundColor: "#334155",
    borderRadius: 10,
    paddingVertical: 11,
    alignItems: "center",
    marginBottom: 12,
  },
  secondaryButtonText: {
    color: "#fff",
    fontSize: 17,
    fontWeight: "700",
  },
  listContent: {
    gap: 10,
    paddingBottom: 24,
  },
  empty: {
    color: "#cbd5e1",
    fontSize: 18,
    textAlign: "center",
    marginTop: 30,
  },
  card: {
    backgroundColor: "#0f172a",
    borderWidth: 1,
    borderColor: "#334155",
    borderRadius: 12,
    padding: 12,
    gap: 6,
  },
  cardTime: {
    color: "#94a3b8",
    fontSize: 14,
  },
  cardTopics: {
    color: "#f8fafc",
    fontSize: 20,
    fontWeight: "700",
  },
  cardSummary: {
    color: "#cbd5e1",
    fontSize: 16,
  },
});
