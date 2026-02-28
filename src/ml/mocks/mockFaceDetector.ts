import { type DetectedFace } from "@/src/domain/types";
import { type FaceDetector, type FrameInput } from "@/src/ml/interfaces";

const DETECTOR_INTERVAL_MS = 1400;

export class MockFaceDetector implements FaceDetector {
  private lastDetectionAt = 0;

  async detect(frame: FrameInput): Promise<DetectedFace[]> {
    // TODO(real-ml): Replace this with real face detection over camera frame pixels.
    if (frame.capturedAt - this.lastDetectionAt < DETECTOR_INTERVAL_MS) {
      return [];
    }

    this.lastDetectionAt = frame.capturedAt;
    const shouldDetectFace = Math.floor(frame.capturedAt / DETECTOR_INTERVAL_MS) % 2 === 0;
    if (!shouldDetectFace) {
      return [];
    }

    return [
      {
        id: `mock-face-${frame.capturedAt}`,
        bounds: { x: 0.12, y: 0.18, width: 0.42, height: 0.36 },
        cropToken: frame.token,
      },
    ];
  }
}
