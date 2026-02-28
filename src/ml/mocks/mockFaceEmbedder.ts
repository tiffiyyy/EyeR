import { type EmbeddingVector } from "@/src/domain/types";
import { type FaceEmbedder } from "@/src/ml/interfaces";

const VECTOR_SIZE = 32;

function seededValue(seed: string, index: number): number {
  let hash = 7;
  for (let cursor = 0; cursor < seed.length; cursor += 1) {
    hash = (hash * 31 + seed.charCodeAt(cursor) + index) % 9973;
  }
  return (hash % 1000) / 1000;
}

export class MockFaceEmbedder implements FaceEmbedder {
  async embed(faceCrop: string): Promise<EmbeddingVector> {
    // TODO(real-ml): Replace this deterministic vector with model inference.
    const vector = new Array(VECTOR_SIZE).fill(0).map((_, index) => seededValue(faceCrop, index));
    return vector;
  }
}
