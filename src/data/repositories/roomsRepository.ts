import { getDatabase } from "@/src/data/db/client";
import { generateId, nowIso } from "@/src/data/utils";
import { type EmbeddingVector, type KnownRoomEmbedding, type Room, type RoomEmbedding, type RoomWithEmbeddings } from "@/src/domain/types";

type RoomRow = {
    id: string;
    name: string;
    thumbnail_uri: string | null;
    created_at: string;
    updated_at: string;
};

type RoomEmbeddingRow = {
    id: string;
    room_id: string;
    vector_json: string;
    source_photo_uri: string | null;
    created_at: string;
    name?: string;
};

export type CreateRoomInput = {
    name: string;
    thumbnailUri?: string | null;
    embeddings: {
        vector: EmbeddingVector;
        sourcePhotoUri?: string | null;
    }[];
};

function mapRoom(row: RoomRow): Room {
    return {
        id: row.id,
        name: row.name,
        thumbnailUri: row.thumbnail_uri,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
    };
}

function mapRoomEmbedding(row: RoomEmbeddingRow): RoomEmbedding {
    return {
        id: row.id,
        roomId: row.room_id,
        vector: JSON.parse(row.vector_json) as EmbeddingVector,
        sourcePhotoUri: row.source_photo_uri,
        createdAt: row.created_at,
    };
}

export class RoomsRepository {
    async list(): Promise<Room[]> {
        const db = await getDatabase();
        const rows = await db.getAllAsync<RoomRow>(
            "SELECT * FROM rooms ORDER BY updated_at DESC;"
        );
        return rows.map(mapRoom);
    }

    async getById(id: string): Promise<RoomWithEmbeddings | null> {
        const db = await getDatabase();
        const roomRow = await db.getFirstAsync<RoomRow>(
            "SELECT * FROM rooms WHERE id = ?;",
            [id]
        );
        if (!roomRow) {
            return null;
        }

        const embeddingRows = await db.getAllAsync<RoomEmbeddingRow>(
            "SELECT * FROM room_embeddings WHERE room_id = ? ORDER BY created_at ASC;",
            [id]
        );

        return {
            room: mapRoom(roomRow),
            embeddings: embeddingRows.map(mapRoomEmbedding),
        };
    }

    async create(input: CreateRoomInput): Promise<string> {
        const db = await getDatabase();
        const roomId = generateId("room");
        const createdAt = nowIso();

        await db.runAsync(
            `INSERT INTO rooms (id, name, thumbnail_uri, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?);`,
            [roomId, input.name.trim(), input.thumbnailUri ?? null, createdAt, createdAt]
        );

        for (const embedding of input.embeddings) {
            await db.runAsync(
                `INSERT INTO room_embeddings (id, room_id, vector_json, source_photo_uri, created_at)
         VALUES (?, ?, ?, ?, ?);`,
                [
                    generateId("room_embedding"),
                    roomId,
                    JSON.stringify(embedding.vector),
                    embedding.sourcePhotoUri ?? null,
                    nowIso(),
                ]
            );
        }

        return roomId;
    }

    async delete(roomId: string): Promise<void> {
        const db = await getDatabase();
        await db.runAsync("DELETE FROM rooms WHERE id = ?;", [roomId]);
    }

    async count(): Promise<number> {
        const db = await getDatabase();
        const result = await db.getFirstAsync<{ count: number }>("SELECT COUNT(*) as count FROM rooms;");
        return result?.count ?? 0;
    }

    async listKnownEmbeddings(): Promise<KnownRoomEmbedding[]> {
        const db = await getDatabase();
        const rows = await db.getAllAsync<RoomEmbeddingRow>(
            `SELECT re.id, re.room_id, re.vector_json, re.source_photo_uri, re.created_at, r.name
       FROM room_embeddings re
       INNER JOIN rooms r ON r.id = re.room_id;`
        );
        return rows.map((row) => ({
            roomId: row.room_id,
            roomName: row.name ?? "Unknown Room",
            embedding: JSON.parse(row.vector_json) as EmbeddingVector,
        }));
    }
}
