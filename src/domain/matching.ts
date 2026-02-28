import { type EmbeddingVector, type FaceMatchResult, type KnownEmbedding } from "./types";

export const DEFAULT_MATCH_THRESHOLD = 0.9;

export function cosineSimilarity(a: EmbeddingVector, b: EmbeddingVector): number {
  if (a.length === 0 || b.length === 0 || a.length !== b.length) {
    return -1;
  }

  let dot = 0;
  let normA = 0;
  let normB = 0;

  for (let index = 0; index < a.length; index += 1) {
    dot += a[index] * b[index];
    normA += a[index] * a[index];
    normB += b[index] * b[index];
  }

  const denominator = Math.sqrt(normA) * Math.sqrt(normB);
  if (denominator === 0) {
    return -1;
  }

  return dot / denominator;
}

export function matchAgainstKnownEmbeddings(
  probeEmbedding: EmbeddingVector,
  knownEmbeddings: KnownEmbedding[],
  threshold = DEFAULT_MATCH_THRESHOLD
): FaceMatchResult {
  if (knownEmbeddings.length === 0) {
    return {
      personId: null,
      personName: "Unknown",
      relationship: null,
      similarity: 0,
      isUnknown: true,
    };
  }

  let best = knownEmbeddings[0];
  let bestSimilarity = cosineSimilarity(probeEmbedding, knownEmbeddings[0].embedding);

  for (let index = 1; index < knownEmbeddings.length; index += 1) {
    const candidate = knownEmbeddings[index];
    const similarity = cosineSimilarity(probeEmbedding, candidate.embedding);
    if (similarity > bestSimilarity) {
      best = candidate;
      bestSimilarity = similarity;
    }
  }

  if (bestSimilarity < threshold) {
    return {
      personId: null,
      personName: "Unknown",
      relationship: null,
      similarity: bestSimilarity,
      isUnknown: true,
    };
  }

  return {
    personId: best.personId,
    personName: best.personName,
    relationship: best.relationship,
    similarity: bestSimilarity,
    isUnknown: false,
  };
}
