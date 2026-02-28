# EyeRemember

EyeRemember is an Expo + React Native + TypeScript mobile app that helps Alzheimer’s patients recognize familiar people and recall recent conversation context.

## Features

- `Camera` tab with local-only mock face recognition pipeline and overlay cards for matched people.
- `People` tab with local SQLite CRUD:
  - list people with thumbnail
  - add person (name + relationship + 4-5 photos)
  - generate/store per-photo embeddings plus averaged reference embedding
  - delete person (embeddings cascade delete)
- `Memories` tab with local topic memory:
  - optional microphone permission request
  - placeholder topic extraction
  - list and search conversation memories

## Architecture

- `app/`: Expo Router navigation and route screens.
- `src/domain/`: core types, matching strategy, enrollment averaging, topic extraction.
- `src/data/`: SQLite setup, schema migration SQL, repositories.
- `src/ml/`: model interfaces, mock detector/embedder, matcher adapter, recognition pipeline.

## Matching Strategy

- Uses cosine similarity in `src/domain/matching.ts`.
- Returns best match only when similarity is above `DEFAULT_MATCH_THRESHOLD`.
- Otherwise classifies as `Unknown`.
- Camera UI currently hides unknown matches to reduce noise.

## Privacy

- Local-first by default.
- No server upload path is implemented for images/audio.
- Camera and microphone permissions include explicit rationale.

## Run

```bash
npm install
npm run start
```

## Key TODO Hooks for Real ML

- `TODO(real-ml)` in `src/ml/mocks/mockFaceDetector.ts`
- `TODO(real-ml)` in `src/ml/mocks/mockFaceEmbedder.ts`
- `TODO(real-ml)` in `src/ml/pipeline/recognitionPipeline.ts`
- `TODO(real-nlp)` in `src/domain/topicExtraction.ts`
- `TODO(real-nlp)` in `app/(tabs)/memories.tsx`
