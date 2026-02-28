# EyeRemember Implementation Task List

## 1) Project foundation

- [ ] Initialize Expo + TypeScript app with Expo Router tabs.
- [ ] Create tab routes: `Camera`, `People`, `Memories`.
- [ ] Install core packages: camera, image picker, sqlite, audio, file-system.
- [ ] Add permission strings in config (camera + microphone).
- [ ] Define folder boundaries: `app/`, `src/domain`, `src/data`, `src/ml`, `src/ui`.

## 2) Domain layer (pure logic)

- [ ] Define types: `Person`, `PersonEmbedding`, `MemoryRecord`, `DetectedFace`, `FaceMatchResult`, `KnownEmbedding`.
- [ ] Implement cosine similarity utility.
- [ ] Implement face matching with threshold (`Unknown` fallback).
- [ ] Implement embedding averaging for enrollment.
- [ ] Add placeholder topic extraction function.
- [ ] Add constants for thresholds and loop intervals.

## 3) Data layer (SQLite local-first)

- [ ] Create DB client singleton.
- [ ] Write schema/migrations:
  - [ ] `people`
  - [ ] `person_embeddings` (FK + cascade delete)
  - [ ] `memories`
- [ ] Implement DB init bootstrap at app startup.
- [ ] Implement `PeopleRepository`:
  - [ ] list
  - [ ] get by id (with embeddings)
  - [ ] create (person + embeddings)
  - [ ] delete
  - [ ] list known embeddings for matcher
- [ ] Implement `MemoriesRepository`:
  - [ ] create
  - [ ] list
  - [ ] search

## 4) ML abstraction layer (swappable)

- [ ] Define interfaces:
  - [ ] `FaceDetector.detect(frame)`
  - [ ] `FaceEmbedder.embed(faceCrop)`
  - [ ] `FaceMatcher.match(embedding, known)`
- [ ] Implement mock detector (controlled periodic detections).
- [ ] Implement mock embedder (deterministic vector output).
- [ ] Implement matcher adapter to domain matching logic.
- [ ] Build recognition pipeline orchestrator (detect → embed → match).
- [ ] Add clear `TODO(real-ml)` integration points.

## 5) People feature (CRUD + enrollment)

- [ ] People list screen (name, relationship, thumbnail).
- [ ] Add-person screen:
  - [ ] name + relationship form
  - [ ] capture/pick 4–5 photos
  - [ ] generate embedding per photo
  - [ ] average reference embedding
  - [ ] save person + embeddings
- [ ] Person detail screen:
  - [ ] show profile info + stored photos
  - [ ] delete person flow
- [ ] Refresh list/detail on navigation focus.

## 6) Camera Mode feature

- [ ] Request camera permission with clear privacy copy.
- [ ] Render live camera preview.
- [ ] Load known embeddings from local DB.
- [ ] Implement throttled recognition loop (every N ms):
  - [ ] build frame input
  - [ ] run pipeline
  - [ ] map results to overlay view models
- [ ] Show overlay cards with `name + relationship`.
- [ ] If no confident match, treat as `Unknown`.
- [ ] If person not in DB, show nothing.
- [ ] Add pause/resume recognition control.

## 7) Memories feature (optional extension)

- [ ] Request microphone permission.
- [ ] Add capture action (stub/placeholder logic initially).
- [ ] Extract placeholder topics and create memory records.
- [ ] Memories list UI with timestamp + topics + optional summary.
- [ ] Search memories by topic/summary text.
- [ ] Add `TODO(real-nlp)` for real transcription/topic extraction.

## 8) Accessibility + UX polish

- [ ] Use larger text sizes across key screens.
- [ ] Keep high contrast colors for readability.
- [ ] Minimize taps for common flows.
- [ ] Ensure clear empty/loading/error states.
- [ ] Validate older-user friendly button sizes and spacing.

## 9) Privacy, correctness, and quality

- [ ] Confirm no network upload path for images/audio.
- [ ] Verify permission prompts are explicit and accurate.
- [ ] Add basic error handling around camera/db/media actions.
- [ ] Run type-check + lint and fix issues.
- [ ] Manual smoke tests:
  - [ ] add person
  - [ ] recognize in camera (mock)
  - [ ] add/search memory
  - [ ] delete person
- [ ] Update README with architecture + real-ML TODO handoff.
