export type EmbeddingVector = number[];

export type Person = {
  id: string;
  name: string;
  relationship: string;
  thumbnailUri?: string | null;
  createdAt: string;
  updatedAt: string;
};

export type PersonEmbedding = {
  id: string;
  personId: string;
  vector: EmbeddingVector;
  sourcePhotoUri?: string | null;
  createdAt: string;
};

export type PersonWithEmbeddings = {
  person: Person;
  embeddings: PersonEmbedding[];
};

export type MemoryRecord = {
  id: string;
  timestamp: string;
  topics: string[];
  summary?: string | null;
};

export type KnownEmbedding = {
  personId: string;
  personName: string;
  relationship: string;
  embedding: EmbeddingVector;
};

export type DetectedFace = {
  id: string;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  cropToken: string;
};

export type FaceMatchResult = {
  personId: string | null;
  personName: string;
  relationship: string | null;
  similarity: number;
  isUnknown: boolean;
};
