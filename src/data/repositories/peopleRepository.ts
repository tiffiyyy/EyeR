import { type SQLiteRunResult } from "expo-sqlite";

import { getDatabase } from "@/src/data/db/client";
import { generateId, nowIso } from "@/src/data/utils";
import { type EmbeddingVector, type KnownEmbedding, type Person, type PersonEmbedding, type PersonWithEmbeddings } from "@/src/domain/types";

type PersonRow = {
  id: string;
  name: string;
  relationship: string;
  thumbnail_uri: string | null;
  created_at: string;
  updated_at: string;
};

type EmbeddingRow = {
  id: string;
  person_id: string;
  vector_json: string;
  source_photo_uri: string | null;
  created_at: string;
  name?: string;
  relationship?: string;
};

export type CreatePersonInput = {
  name: string;
  relationship: string;
  thumbnailUri?: string | null;
  embeddings: {
    vector: EmbeddingVector;
    sourcePhotoUri?: string | null;
  }[];
};

function mapPerson(row: PersonRow): Person {
  return {
    id: row.id,
    name: row.name,
    relationship: row.relationship,
    thumbnailUri: row.thumbnail_uri,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapEmbedding(row: EmbeddingRow): PersonEmbedding {
  return {
    id: row.id,
    personId: row.person_id,
    vector: JSON.parse(row.vector_json) as EmbeddingVector,
    sourcePhotoUri: row.source_photo_uri,
    createdAt: row.created_at,
  };
}

export class PeopleRepository {
  async list(): Promise<Person[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<PersonRow>(
      "SELECT * FROM people ORDER BY updated_at DESC;"
    );
    return rows.map(mapPerson);
  }

  async getById(id: string): Promise<PersonWithEmbeddings | null> {
    const db = await getDatabase();
    const personRow = await db.getFirstAsync<PersonRow>(
      "SELECT * FROM people WHERE id = ?;",
      [id]
    );
    if (!personRow) {
      return null;
    }

    const embeddingRows = await db.getAllAsync<EmbeddingRow>(
      "SELECT * FROM person_embeddings WHERE person_id = ? ORDER BY created_at ASC;",
      [id]
    );

    return {
      person: mapPerson(personRow),
      embeddings: embeddingRows.map(mapEmbedding),
    };
  }

  async create(input: CreatePersonInput): Promise<string> {
    const db = await getDatabase();
    const personId = generateId("person");
    const createdAt = nowIso();

    await db.runAsync(
      `INSERT INTO people (id, name, relationship, thumbnail_uri, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?);`,
      [personId, input.name.trim(), input.relationship.trim(), input.thumbnailUri ?? null, createdAt, createdAt]
    );

    for (const embedding of input.embeddings) {
      await db.runAsync(
        `INSERT INTO person_embeddings (id, person_id, vector_json, source_photo_uri, created_at)
         VALUES (?, ?, ?, ?, ?);`,
        [
          generateId("embedding"),
          personId,
          JSON.stringify(embedding.vector),
          embedding.sourcePhotoUri ?? null,
          nowIso(),
        ]
      );
    }

    return personId;
  }

  async delete(personId: string): Promise<void> {
    const db = await getDatabase();
    await db.runAsync("DELETE FROM people WHERE id = ?;", [personId]);
  }

  async count(): Promise<number> {
    const db = await getDatabase();
    const result = await db.getFirstAsync<{ count: number }>("SELECT COUNT(*) as count FROM people;");
    return result?.count ?? 0;
  }

  async listKnownEmbeddings(): Promise<KnownEmbedding[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<EmbeddingRow>(
      `SELECT pe.id, pe.person_id, pe.vector_json, pe.source_photo_uri, pe.created_at, p.name, p.relationship
       FROM person_embeddings pe
       INNER JOIN people p ON p.id = pe.person_id;`
    );
    return rows.map((row) => ({
      personId: row.person_id,
      personName: row.name ?? "Unknown",
      relationship: row.relationship ?? "",
      embedding: JSON.parse(row.vector_json) as EmbeddingVector,
    }));
  }
}

export async function runQueryForDebugging(query: string): Promise<SQLiteRunResult> {
  const db = await getDatabase();
  return db.runAsync(query);
}
