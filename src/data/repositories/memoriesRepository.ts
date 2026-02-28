import { getDatabase } from "@/src/data/db/client";
import { generateId, nowIso } from "@/src/data/utils";
import { type MemoryRecord } from "@/src/domain/types";

type MemoryRow = {
  id: string;
  timestamp: string;
  topics_json: string;
  summary: string | null;
};

function mapMemory(row: MemoryRow): MemoryRecord {
  return {
    id: row.id,
    timestamp: row.timestamp,
    topics: JSON.parse(row.topics_json) as string[],
    summary: row.summary,
  };
}

export type CreateMemoryInput = {
  topics: string[];
  summary?: string | null;
};

export class MemoriesRepository {
  async create(input: CreateMemoryInput): Promise<string> {
    const db = await getDatabase();
    const id = generateId("memory");
    await db.runAsync(
      "INSERT INTO memories (id, timestamp, topics_json, summary) VALUES (?, ?, ?, ?);",
      [id, nowIso(), JSON.stringify(input.topics), input.summary ?? null]
    );
    return id;
  }

  async list(): Promise<MemoryRecord[]> {
    const db = await getDatabase();
    const rows = await db.getAllAsync<MemoryRow>("SELECT * FROM memories ORDER BY timestamp DESC;");
    return rows.map(mapMemory);
  }

  async search(query: string): Promise<MemoryRecord[]> {
    const db = await getDatabase();
    const normalized = `%${query.toLowerCase()}%`;
    const rows = await db.getAllAsync<MemoryRow>(
      `SELECT * FROM memories
       WHERE LOWER(topics_json) LIKE ? OR LOWER(COALESCE(summary, '')) LIKE ?
       ORDER BY timestamp DESC;`,
      [normalized, normalized]
    );
    return rows.map(mapMemory);
  }
}
