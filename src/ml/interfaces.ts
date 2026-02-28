import { type DetectedFace, type EmbeddingVector, type FaceMatchResult, type KnownEmbedding } from "@/src/domain/types";

export type FrameInput = {
  token: string;
  capturedAt: number;
};

export interface FaceDetector {
  detect(frame: FrameInput): Promise<DetectedFace[]>;
}

export interface FaceEmbedder {
  embed(faceCrop: string): Promise<EmbeddingVector>;
}

export interface FaceMatcher {
  match(embedding: EmbeddingVector, knownEmbeddings: KnownEmbedding[]): FaceMatchResult;
}
