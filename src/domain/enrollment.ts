import { type EmbeddingVector } from "./types";

export function averageEmbeddings(embeddings: EmbeddingVector[]): EmbeddingVector {
  if (embeddings.length === 0) {
    return [];
  }

  const dimensions = embeddings[0].length;
  const accumulator = new Array(dimensions).fill(0) as number[];

  for (const embedding of embeddings) {
    for (let index = 0; index < dimensions; index += 1) {
      accumulator[index] += embedding[index] ?? 0;
    }
  }

  return accumulator.map((value) => value / embeddings.length);
}
