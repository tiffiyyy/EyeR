import { useFocusEffect } from "@react-navigation/native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useCallback, useState } from "react";
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import { roomsRepository } from "@/src/data/repositories";
import { type RoomWithEmbeddings } from "@/src/domain/types";

export default function RoomDetailScreen() {
    const { id } = useLocalSearchParams<{ id: string }>();
    const router = useRouter();
    const [record, setRecord] = useState<RoomWithEmbeddings | null>(null);

    const loadRoom = useCallback(async () => {
        if (!id) {
            return;
        }
        const room = await roomsRepository.getById(id);
        setRecord(room);
    }, [id]);

    useFocusEffect(
        useCallback(() => {
            loadRoom().catch((error) => console.error("Failed to load room", error));
        }, [loadRoom])
    );

    const onDelete = () => {
        if (!id) {
            return;
        }
        Alert.alert("Delete room?", "This will remove its embeddings too.", [
            { text: "Cancel", style: "cancel" },
            {
                text: "Delete",
                style: "destructive",
                onPress: async () => {
                    await roomsRepository.delete(id);
                    router.back();
                },
            },
        ]);
    };

    if (!record) {
        return (
            <View style={styles.emptyState}>
                <Text style={styles.emptyText}>Room not found.</Text>
            </View>
        );
    }

    const uniquePhotos = Array.from(
        new Set(record.embeddings.map((item) => item.sourcePhotoUri).filter((value): value is string => !!value))
    );

    return (
        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
            <Text style={styles.name}>{record.room.name}</Text>
            <Text style={styles.meta}>Embeddings stored: {record.embeddings.length}</Text>

            <View style={styles.photoWrap}>
                {uniquePhotos.map((uri) => (
                    <Image key={uri} source={{ uri }} style={styles.photo} />
                ))}
            </View>

            <Pressable onPress={onDelete} style={styles.deleteButton}>
                <Text style={styles.deleteText}>Delete Room</Text>
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
