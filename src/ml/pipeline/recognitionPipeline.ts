import { type FaceMatchResult, type KnownEmbedding } from "@/src/domain/types";
import { type FaceDetector, type FaceEmbedder, type FaceMatcher, type FrameInput } from "@/src/ml/interfaces";

export type RecognitionPipelineResult = {
  faceId: string;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  match: FaceMatchResult;
};

export class RecognitionPipeline {
  constructor(
    private readonly detector: FaceDetector,
    private readonly embedder: FaceEmbedder,
    private readonly matcher: FaceMatcher
  ) {}

  async run(frame: FrameInput, knownEmbeddings: KnownEmbedding[]): Promise<RecognitionPipelineResult[]> {
    const faces = await this.detector.detect(frame);
    if (faces.length === 0) {
      return [];
    }

    const results: RecognitionPipelineResult[] = [];
    for (const face of faces) {
      // TODO(real-ml): Pass a real face crop image buffer instead of a token.
      let probeEmbedding = await this.embedder.embed(face.cropToken);

      // Mock-only branch to make recognized overlays observable during development.
      if (knownEmbeddings.length > 0 && Math.floor(frame.capturedAt / 4000) % 2 === 0) {
        const simulatedIndex = Math.floor(frame.capturedAt / 4000) % knownEmbeddings.length;
        const baseline = knownEmbeddings[simulatedIndex].embedding;
        probeEmbedding = baseline.map((value, index) => {
          const offset = ((frame.capturedAt + index) % 20) / 1000;
          return value + offset;
        });
      }

      const match = this.matcher.match(probeEmbedding, knownEmbeddings);
      results.push({ faceId: face.id, bounds: face.bounds, match });
    }

    return results;
  }
}
