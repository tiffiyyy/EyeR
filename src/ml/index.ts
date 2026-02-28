import { DefaultFaceMatcher } from "@/src/ml/defaultFaceMatcher";
import { MockFaceDetector } from "@/src/ml/mocks/mockFaceDetector";
import { MockFaceEmbedder } from "@/src/ml/mocks/mockFaceEmbedder";
import { RecognitionPipeline } from "@/src/ml/pipeline/recognitionPipeline";

const detector = new MockFaceDetector();
export const faceEmbedder = new MockFaceEmbedder();
const matcher = new DefaultFaceMatcher();

export const recognitionPipeline = new RecognitionPipeline(detector, faceEmbedder, matcher);
