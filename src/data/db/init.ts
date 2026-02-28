import { getDatabase } from "@/src/data/db/client";
import { schemaSql } from "@/src/data/db/migrations";

let initialized = false;

export async function initializeDatabase(): Promise<void> {
  if (initialized) {
    return;
  }

  const db = await getDatabase();
  await db.execAsync(schemaSql);
  initialized = true;
}
