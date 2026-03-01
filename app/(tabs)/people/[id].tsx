import { useFocusEffect } from "@react-navigation/native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useState } from "react";
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { interactionsRepository, peopleRepository } from "@/src/data/repositories";
import { type InteractionRecord, type PersonWithEmbeddings } from "@/src/domain/types";

// note: this file serves as a template file/function 
// for each person created, one of these files will be "created" (so that their person details can be viewed)
export default function PersonDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const [record, setRecord] = useState<PersonWithEmbeddings | null>(null);
  const [interactions, setInteractions] = useState<InteractionRecord[]>([]);

  // we use "useCallback" to ensure that person data remains intact 
  const loadPerson = useCallback(async () => {
    if (!id) {
      return;
    }
    // waits until person is returned from the db then set the record 
    const person = await peopleRepository.getById(id);
    const personInteractions = await interactionsRepository.listByPerson(id);
    setRecord(person);
    setInteractions(personInteractions);
  }, [id]);

  // if person cannot be loaded, throw an error 
  useFocusEffect(
    useCallback(() => {
      loadPerson().catch((error) => console.error("Failed to load person", error));
    }, [loadPerson])
  );

  // function to delete person from db 
  const onDelete = () => {
    if (!id) {
      return;
    }
    Alert.alert("Delete person?", "This action cannot be undone.", [
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

  // if record does not exist, throw an error 
  if (!record) {
    return (
      <View style={styles.emptyState}>
        <Text style={styles.emptyText}>Person not found.</Text>
      </View>
    );
  }

  // removes any duplicate images uploaded and creates an array of images to be displayed for each person 
  const uniquePhotos = Array.from(
    new Set(record.embeddings.map((item) => item.sourcePhotoUri).filter((value): value is string => !!value))
  );

  // tsx code for page layout 
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

      <Text style={[styles.meta, { marginTop: 24, marginBottom: 8, fontSize: 18, fontWeight: "bold" }]}>
        Recent Interactions ({interactions.length})
      </Text>
      {interactions.length === 0 ? (
        <Text style={styles.meta}>No conversations recorded yet.</Text>
      ) : (
        interactions.map((interaction) => (
          <View key={interaction.id} style={styles.interactionCard}>
            <Text style={styles.interactionTime}>{new Date(interaction.timestamp).toLocaleString()}</Text>
            <Text style={styles.interactionTranscript}>{interaction.transcript}</Text>
          </View>
        ))
      )}

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
  interactionCard: {
    backgroundColor: "#0f172a",
    borderWidth: 1,
    borderColor: "#334155",
    borderRadius: 12,
    padding: 12,
    marginTop: 8,
    gap: 4,
  },
  interactionTime: {
    color: "#94a3b8",
    fontSize: 14,
  },
  interactionTranscript: {
    color: "#f8fafc",
    fontSize: 16,
    lineHeight: 22,
  },
});
