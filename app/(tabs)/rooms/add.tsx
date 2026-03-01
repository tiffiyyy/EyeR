import * as ImagePicker from "expo-image-picker";
import { router } from "expo-router";
import { useMemo, useState } from "react";
import { Alert, Image, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";

import { roomsRepository } from "@/src/data/repositories";
import { averageEmbeddings } from "@/src/domain/enrollment";
import { faceEmbedder } from "@/src/ml";

const MIN_PHOTOS = 4;
const MAX_PHOTOS = 5;

export default function AddRoomScreen() {
    const [name, setName] = useState("");
    const [photoUris, setPhotoUris] = useState<string[]>([]);
    const [isSaving, setIsSaving] = useState(false);

    const canAddMorePhotos = photoUris.length < MAX_PHOTOS;
    const canSave = useMemo(
        () => name.trim().length > 0 && photoUris.length >= MIN_PHOTOS && !isSaving,
        [isSaving, name, photoUris.length]
    );

    const appendPhoto = (uri: string) => {
        setPhotoUris((current) => {
            if (current.length >= MAX_PHOTOS) {
                return current;
            }
            return [...current, uri];
        });
    };

    const pickFromLibrary = async () => {
        if (!canAddMorePhotos) {
            return;
        }
        const result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: "images",
            allowsEditing: false,
            quality: 0.6,
        });
        if (!result.canceled) {
            appendPhoto(result.assets[0].uri);
        }
    };

    const captureWithCamera = async () => {
        if (!canAddMorePhotos) {
            return;
        }
        const result = await ImagePicker.launchCameraAsync({
            mediaTypes: "images",
            allowsEditing: false,
            quality: 0.6,
        });
        if (!result.canceled) {
            appendPhoto(result.assets[0].uri);
        }
    };

    const saveRoom = async () => {
        if (!canSave) {
            return;
        }
        setIsSaving(true);
        try {
            // NOTE: We are using faceEmbedder as a placeholder for room embedding logic for now
            const vectors = await Promise.all(photoUris.map((uri) => faceEmbedder.embed(uri)));
            const referenceEmbedding = averageEmbeddings(vectors);
            const embeddings = [
                ...vectors.map((vector, index) => ({
                    vector,
                    sourcePhotoUri: photoUris[index],
                })),
                {
                    vector: referenceEmbedding,
                    sourcePhotoUri: null,
                },
            ];

            await roomsRepository.create({
                name,
                thumbnailUri: photoUris[0],
                embeddings,
            });

            router.back();
        } catch (error) {
            Alert.alert("Unable to save room", "Try again.");
            console.error(error);
        } finally {
            setIsSaving(false);
        }
    };

    return (
        <ScrollView style={styles.container} contentContainerStyle={styles.content}>
            <Text style={styles.label}>Room Name</Text>
            <TextInput
                placeholder="e.g. Living Room, Office"
                placeholderTextColor="#94a3b8"
                value={name}
                onChangeText={setName}
                style={styles.input}
            />

            <Text style={styles.helperText}>
                Add {MIN_PHOTOS} to {MAX_PHOTOS} photos of the room ({photoUris.length}/{MAX_PHOTOS}).
            </Text>

            <View style={styles.row}>
                <Pressable onPress={captureWithCamera} style={[styles.actionButton, !canAddMorePhotos && styles.disabledButton]}>
                    <Text style={styles.actionText}>Capture Photo</Text>
                </Pressable>
                <Pressable onPress={pickFromLibrary} style={[styles.actionButton, !canAddMorePhotos && styles.disabledButton]}>
                    <Text style={styles.actionText}>Pick Photo</Text>
                </Pressable>
            </View>

            <View style={styles.photoWrap}>
                {photoUris.map((uri) => (
                    <Image key={uri} source={{ uri }} style={styles.photo} />
                ))}
            </View>

            <Pressable onPress={saveRoom} style={[styles.saveButton, !canSave && styles.disabledButton]}>
                <Text style={styles.saveText}>{isSaving ? "Saving..." : "Save Room"}</Text>
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
    label: {
        color: "#f8fafc",
        fontSize: 18,
        fontWeight: "700",
    },
    input: {
        backgroundColor: "#0f172a",
        color: "#f8fafc",
        borderColor: "#334155",
        borderWidth: 1,
        borderRadius: 12,
        paddingHorizontal: 12,
        paddingVertical: 12,
        fontSize: 18,
    },
    helperText: {
        color: "#cbd5e1",
        fontSize: 16,
        marginTop: 4,
    },
    row: {
        flexDirection: "row",
        gap: 10,
    },
    actionButton: {
        flex: 1,
        backgroundColor: "#16a34a",
        borderRadius: 10,
        paddingVertical: 12,
        alignItems: "center",
    },
    actionText: {
        color: "#fff",
        fontSize: 16,
        fontWeight: "700",
    },
    photoWrap: {
        flexDirection: "row",
        flexWrap: "wrap",
        gap: 8,
        marginTop: 10,
    },
    photo: {
        width: 90,
        height: 90,
        borderRadius: 10,
    },
    saveButton: {
        marginTop: 16,
        backgroundColor: "#15803d",
        borderRadius: 12,
        paddingVertical: 14,
        alignItems: "center",
    },
    saveText: {
        color: "#fff",
        fontSize: 18,
        fontWeight: "800",
    },
    disabledButton: {
        opacity: 0.45,
    },
});
