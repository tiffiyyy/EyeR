import { DefaultFaceMatcher } from "@/src/ml/defaultFaceMatcher";
import { ArcFaceEmbedder } from "@/src/ml/models/ArcFaceEmbedder";
import { RetinaFaceDetector } from "@/src/ml/models/RetinaFaceDetector";
import { RecognitionPipeline } from "@/src/ml/pipeline/recognitionPipeline";

const detector = new RetinaFaceDetector();
export const faceEmbedder = new ArcFaceEmbedder();
const matcher = new DefaultFaceMatcher();

export const recognitionPipeline = new RecognitionPipeline(detector, faceEmbedder, matcher);
