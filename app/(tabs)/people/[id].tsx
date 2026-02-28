import { useFocusEffect } from "@react-navigation/native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useState } from "react";
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { peopleRepository } from "@/src/data/repositories";
import { type PersonWithEmbeddings } from "@/src/domain/types";

export default function PersonDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [record, setRecord] = useState<PersonWithEmbeddings | null>(null);

  const loadPerson = useCallback(async () => {
    if (!id) {
      return;
    }
    const person = await peopleRepository.getById(id);
    setRecord(person);
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      loadPerson().catch((error) => console.error("Failed to load person", error));
    }, [loadPerson])
  );

  const onDelete = () => {
    if (!id) {
      return;
    }
    Alert.alert("Delete person?", "This will remove their embeddings too.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Delete",
        style: "destructive",
        onPress: async () => {
          await peopleRepository.delete(id);
          router.back();
        },
      },
    ]);
  };

  if (!record) {
    return (
      <View style={styles.emptyState}>
        <Text style={styles.emptyText}>Person not found.</Text>
      </View>
    );
  }

  const uniquePhotos = Array.from(
    new Set(record.embeddings.map((item) => item.sourcePhotoUri).filter((value): value is string => !!value))
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.name}>{record.person.name}</Text>
      <Text style={styles.relationship}>{record.person.relationship}</Text>
      <Text style={styles.meta}>Embeddings stored: {record.embeddings.length}</Text>

      <View style={styles.photoWrap}>
        {uniquePhotos.map((uri) => (
          <Image key={uri} source={{ uri }} style={styles.photo} />
        ))}
      </View>

      <Pressable onPress={onDelete} style={styles.deleteButton}>
        <Text style={styles.deleteText}>Delete Person</Text>
      </Pressable>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#020617",
  },
  content: {
    padding: 16,
    gap: 10,
  },
  name: {
    color: "#f8fafc",
    fontSize: 34,
    fontWeight: "800",
  },
  relationship: {
    color: "#cbd5e1",
    fontSize: 22,
    fontWeight: "600",
  },
  meta: {
    color: "#94a3b8",
    fontSize: 16,
  },
  photoWrap: {
    marginTop: 8,
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
  },
  photo: {
    width: 96,
    height: 96,
    borderRadius: 12,
  },
  deleteButton: {
    marginTop: 20,
    backgroundColor: "#b91c1c",
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: "center",
  },
  deleteText: {
    color: "#fff",
    fontSize: 18,
    fontWeight: "700",
  },
  emptyState: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#020617",
  },
  emptyText: {
    color: "#fff",
    fontSize: 20,
  },
});
