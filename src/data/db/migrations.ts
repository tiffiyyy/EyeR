export const schemaSql = `
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  thumbnail_uri TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS person_embeddings (
  id TEXT PRIMARY KEY NOT NULL,
  person_id TEXT NOT NULL,
  vector_json TEXT NOT NULL,
  source_photo_uri TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_person_embeddings_person_id
ON person_embeddings(person_id);

CREATE TABLE IF NOT EXISTS memories (
  id TEXT PRIMARY KEY NOT NULL,
  timestamp TEXT NOT NULL,
  topics_json TEXT NOT NULL,
  summary TEXT
);
`;
