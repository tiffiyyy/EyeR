import { getDatabase } from "@/src/data/db/client";
import { generateId, nowIso } from "@/src/data/utils";
import { type InteractionRecord } from "@/src/domain/types";

type InteractionRow = {
    id: string;
    person_id: string;
    timestamp: string;
    transcript: string;
};

function mapInteraction(row: InteractionRow): InteractionRecord {
    return {
        id: row.id,
        personId: row.person_id,
        timestamp: row.timestamp,
        transcript: row.transcript,
    };
}

export type CreateInteractionInput = {
    personId: string;
    transcript: string;
};

export class InteractionsRepository {
    async create(input: CreateInteractionInput): Promise<string> {
        const db = await getDatabase();
        const id = generateId("interaction");
        await db.runAsync(
            "INSERT INTO interactions (id, person_id, timestamp, transcript) VALUES (?, ?, ?, ?);",
            [id, input.personId, nowIso(), input.transcript]
        );
        return id;
    }

    async listByPerson(personId: string): Promise<InteractionRecord[]> {
        const db = await getDatabase();
        const rows = await db.getAllAsync<InteractionRow>(
            "SELECT * FROM interactions WHERE person_id = ? ORDER BY timestamp DESC;",
            [personId]
        );
        return rows.map(mapInteraction);
    }
}
