import { useFocusEffect } from "@react-navigation/native";
import { router } from "expo-router";
import { useCallback, useState } from "react";
import { FlatList, Image, Pressable, StyleSheet, Text, View } from "react-native";

import { peopleRepository } from "@/src/data/repositories";
import { type Person } from "@/src/domain/types";

export default function PeopleListScreen() {
  const [people, setPeople] = useState<Person[]>([]);

  // we use "useCallback" to ensure that person data remains intact 
  const loadPeople = useCallback(async () => {
    const records = await peopleRepository.list();
    setPeople(records);
  }, []);

  // if person cannot be loaded, throw an error 
  useFocusEffect(
    useCallback(() => {
      loadPeople().catch((error) => console.error("Failed to load people", error));
    }, [loadPeople])
  );

  // tsx code for page layout 
  return (
    <View style={styles.container}>
      <Pressable style={styles.addButton} onPress={() => router.push("/(tabs)/people/add")}>
        <Text style={styles.addButtonText}>Add Person</Text>
      </Pressable>

      {/* flatlist ensures that not all people records will be loaded at once (<- could crash app) */}
      <FlatList
        data={people}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        ListEmptyComponent={<Text style={styles.emptyText}>No people saved yet.</Text>}
        renderItem={({ item }) => (
          // loads person's record/data 
          <Pressable style={styles.card} onPress={() => router.push(`/(tabs)/people/${item.id}`)}>
            {item.thumbnailUri ? (
              <Image source={{ uri: item.thumbnailUri }} style={styles.thumbnail} />
            ) : (
              <View style={[styles.thumbnail, styles.placeholderThumb]} />
            )}
            <View style={styles.cardTextContainer}>
              <Text style={styles.nameText}>{item.name}</Text>
              <Text style={styles.relationshipText}>{item.relationship}</Text>
            </View>
          </Pressable>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#020617",
    padding: 12,
  },
  addButton: {
    backgroundColor: "#1d4ed8",
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: "center",
    marginBottom: 12,
  },
  addButtonText: {
    color: "#fff",
    fontWeight: "700",
    fontSize: 18,
  },
  listContent: {
    gap: 10,
    paddingBottom: 28,
  },
  emptyText: {
    color: "#cbd5e1",
    fontSize: 18,
    textAlign: "center",
    marginTop: 40,
  },
  card: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#0f172a",
    borderColor: "#334155",
    borderWidth: 1,
    borderRadius: 14,
    padding: 10,
    gap: 12,
  },
  thumbnail: {
    width: 56,
    height: 56,
    borderRadius: 28,
  },
  placeholderThumb: {
    backgroundColor: "#334155",
  },
  cardTextContainer: {
    flex: 1,
  },
  nameText: {
    color: "#fff",
    fontSize: 22,
    fontWeight: "800",
  },
  relationshipText: {
    color: "#cbd5e1",
    fontSize: 17,
    fontWeight: "600",
  },
});
