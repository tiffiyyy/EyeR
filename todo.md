# EyeRemember Implementation Task List

## 1) Project foundation

- [x] Initialize Expo + TypeScript app with Expo Router tabs.
- [x] Create tab routes: `Camera`, `People`, `Memories`.
- [x] Install core packages: camera, image picker, sqlite, audio, file-system.
- [x] Add permission strings in config (camera + microphone).
- [x] Define folder boundaries: `app/`, `src/domain`, `src/data`, `src/ml`, `src/ui`.

## 2) Domain layer (pure logic)

- [x] Define types: `Person`, `PersonEmbedding`, `MemoryRecord`, `DetectedFace`, `FaceMatchResult`, `KnownEmbedding`.
- [x] Implement cosine similarity utility.
- [x] Implement face matching with threshold (`Unknown` fallback).
- [x] Implement embedding averaging for enrollment.
- [x] Add placeholder topic extraction function.
- [x] Add constants for thresholds and loop intervals.

## 3) Data layer (SQLite local-first)

- [x] Create DB client singleton.
- [x] Write schema/migrations:
  - [x] `people`
  - [x] `person_embeddings` (FK + cascade delete)
  - [x] `memories`
- [x] Implement DB init bootstrap at app startup.
- [x] Implement `PeopleRepository`:
  - [x] list
  - [x] get by id (with embeddings)
  - [x] create (person + embeddings)
  - [x] delete
  - [x] list known embeddings for matcher
- [x] Implement `MemoriesRepository`:
  - [x] create
  - [x] list
  - [x] search

## 4) ML abstraction layer (swappable)

- [x] Define interfaces:
  - [x] `FaceDetector.detect(frame)`
  - [x] `FaceEmbedder.embed(faceCrop)`
  - [x] `FaceMatcher.match(embedding, known)`
- [x] Implement mock detector (controlled periodic detections).
- [x] Implement mock embedder (deterministic vector output).
- [x] Implement matcher adapter to domain matching logic.
- [x] Build recognition pipeline orchestrator (detect → embed → match).
- [x] Add clear `TODO(real-ml)` integration points.

## 5) People feature (CRUD + enrollment)

- [x] People list screen (name, relationship, thumbnail).
- [x] Add-person screen:
  - [x] name + relationship form
  - [x] capture/pick 4–5 photos
  - [x] generate embedding per photo
  - [x] average reference embedding
  - [x] save person + embeddings
- [x] Person detail screen:
  - [x] show profile info + stored photos
  - [x] delete person flow
- [x] Refresh list/detail on navigation focus.

## 6) Camera Mode feature

- [x] Request camera permission with clear privacy copy.
- [x] Render live camera preview.
- [x] Load known embeddings from local DB.
- [x] Implement throttled recognition loop (every N ms):
  - [x] build frame input
  - [x] run pipeline
  - [x] map results to overlay view models
- [x] Show overlay cards with `name + relationship`.
- [x] If no confident match, treat as `Unknown`.
- [x] If person not in DB, show nothing.
- [x] Add pause/resume recognition control.

## 7) Memories feature (optional extension)

- [x] Request microphone permission.
- [x] Add capture action (stub/placeholder logic initially).
- [x] Extract placeholder topics and create memory records.
- [x] Memories list UI with timestamp + topics + optional summary.
- [x] Search memories by topic/summary text.
- [x] Add `TODO(real-nlp)` for real transcription/topic extraction.

## 8) Accessibility + UX polish

- [x] Use larger text sizes across key screens.
- [x] Keep high contrast colors for readability.
- [x] Minimize taps for common flows.
- [x] Ensure clear empty/loading/error states.
- [x] Validate older-user friendly button sizes and spacing.

## 9) Privacy, correctness, and quality

- [x] Confirm no network upload path for images/audio.
- [x] Verify permission prompts are explicit and accurate.
- [x] Add basic error handling around camera/db/media actions.
- [x] Run type-check + lint and fix issues.
- [x] Manual smoke tests:
  - [x] add person
  - [x] recognize in camera (mock)
  - [x] add/search memory
  - [x] delete person
- [x] Update README with architecture + real-ML TODO handoff.
