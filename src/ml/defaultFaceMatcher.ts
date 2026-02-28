import { matchAgainstKnownEmbeddings } from "@/src/domain/matching";
import { type EmbeddingVector, type FaceMatchResult, type KnownEmbedding } from "@/src/domain/types";
import { type FaceMatcher } from "@/src/ml/interfaces";

export class DefaultFaceMatcher implements FaceMatcher {
  match(embedding: EmbeddingVector, knownEmbeddings: KnownEmbedding[]): FaceMatchResult {
    return matchAgainstKnownEmbeddings(embedding, knownEmbeddings);
  }
}
