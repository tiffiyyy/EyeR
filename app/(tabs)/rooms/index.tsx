import { useFocusEffect } from "@react-navigation/native";
import { router } from "expo-router";
import { useCallback, useState } from "react";
import { FlatList, Image, Pressable, StyleSheet, Text, View } from "react-native";

import { roomsRepository } from "@/src/data/repositories";
import { type Room } from "@/src/domain/types";

export default function RoomsListScreen() {
    const [rooms, setRooms] = useState<Room[]>([]);

    const loadRooms = useCallback(async () => {
        const records = await roomsRepository.list();
        setRooms(records);
    }, []);

    useFocusEffect(
        useCallback(() => {
            loadRooms().catch((error) => console.error("Failed to load rooms", error));
        }, [loadRooms])
    );

    return (
        <View style={styles.container}>
            <Pressable style={styles.addButton} onPress={() => router.push("/(tabs)/rooms/add" as any)}>
                <Text style={styles.addButtonText}>Add Room</Text>
            </Pressable>

            <FlatList
                data={rooms}
                keyExtractor={(item) => item.id}
                contentContainerStyle={styles.listContent}
                ListEmptyComponent={<Text style={styles.emptyText}>No rooms saved yet.</Text>}
                renderItem={({ item }) => (
                    <Pressable style={styles.card} onPress={() => router.push(`/(tabs)/rooms/${item.id}` as any)}>
                        {item.thumbnailUri ? (
                            <Image source={{ uri: item.thumbnailUri }} style={styles.thumbnail} />
                        ) : (
                            <View style={[styles.thumbnail, styles.placeholderThumb]} />
                        )}
                        <View style={styles.cardTextContainer}>
                            <Text style={styles.nameText}>{item.name}</Text>
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
        backgroundColor: "#16a34a",
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
        borderRadius: 12,
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
});
