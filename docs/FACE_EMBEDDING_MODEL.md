# Face Embedding Model for GlimpseH4H

The app uses a **CoreML face-embedding model** to recognize people. The model must be named **`FaceEmbedding.mlmodel`** and added to the GlimpseH4H Xcode target.

## What the app expects

- **Input:** A single image (cropped face). The Vision framework passes the cropped face from the camera or photo; the model can expect a fixed size (e.g. 160×160 or 112×112) — Vision’s `imageCropAndScaleOption = .scaleFill` handles resizing.
- **Output:** One feature that is a **vector of floats** (e.g. 128 or 512 dimensions). The app uses the first output from the model as the embedding and compares with cosine similarity.

Any CoreML model that takes an image and returns one `MLMultiArray` of floats will work.

---

## Option 1: Pre-converted FaceNet-style model (iOS project)

**[ios-facenet-id](https://github.com/daduz11/ios-facenet-id)** provides a full flow to get a CoreML face-embedding model:

1. **Get the TensorFlow FaceNet model** (frozen graph `.pb`):
   - From the [README](https://github.com/daduz11/ios-facenet-id#pre-trained-model): use the [20180402-114759](https://drive.google.com/open?id=1EXPBSXwTaqrSC0OhUdXNmKSh9qJUQ55-) model (Inception ResNet v1, 512-D embeddings).
   - Download and unzip; you need the `.pb` file (often named like `frozen_graph.pb` or similar in that repo’s Python scripts).

2. **Convert to CoreML** using the repo’s Python script:
   - In the `Python` folder they use `tfcoreml` and `coremltools`:
     - Input shape: `[1, 160, 160, 3]` (batch, height, width, RGB).
     - Output name: `embeddings`.
   - Run their `ml_converter.py` (see [Python/ml_converter.py](https://github.com/daduz11/ios-facenet-id/blob/master/Python/ml_converter.py)) to produce a `.mlmodel` file.

3. **Rename and add to Xcode:**
   - Rename the generated `.mlmodel` to **`FaceEmbedding.mlmodel`**.
   - In Xcode: File → Add Files to "GlimpseH4H" → select `FaceEmbedding.mlmodel` and ensure the app target is checked. Xcode will compile it to `FaceEmbedding.mlmodelc` in the bundle.

---

## Option 2: ONNX face embedding → CoreML (script in this repo)

If you have (or download) an **ONNX** face-embedding model, you can convert it to CoreML and then add it to the app.

### Get an ONNX model

- **[haikalmumtaz/facenet-onnx](https://huggingface.co/haikalmumtaz/facenet-onnx)**  
  - 512-dimensional embeddings.  
  - Download the model file from the Hugging Face repo (e.g. `model.onnx` or the name shown on the “Files” tab).

- **[FaceONNX models](https://github.com/FaceONNX/FaceONNX.Models)**  
  - FaceONNX publishes ONNX models for detection and recognition; check their repo for embedding/recognition models and input size (e.g. 112×112 or 160×160).

### Convert ONNX → CoreML

From the project root, with a Python env that has `coremltools` and `onnx`:

```bash
pip install coremltools onnx
python scripts/convert_onnx_to_coreml_face_embedding.py path/to/your_model.onnx
```

The script writes **`FaceEmbedding.mlmodel`** next to the script (or to a path you pass). Add this file to the GlimpseH4H target in Xcode as above.

---

## Option 3: Apple’s Core ML Models

**[Apple Machine Learning Models](https://developers.apple.com/machine-learning/models/)**  
Apple does not currently list a face-embedding model there (they have image classification, object detection, etc.). If they add one that outputs a single embedding vector, you can use it and rename/wrap as needed so the app sees one image input and one vector output named for the first output (our code uses `request.results?.first`).

---

## After adding the model

1. Build the app in Xcode. The model is compiled to `FaceEmbedding.mlmodelc` and shipped in the app.
2. **Onboarding:** When adding or editing a person, the app generates embeddings from each photo and stores them in `Person.faceEmbeddings`.
3. **Camera:** After a face is stable for ~2 seconds, the app computes an embedding and compares it to stored embeddings (cosine similarity). You can tune the match threshold in `IdentificationPipeline` (`matchThreshold`, default 0.7).

If no model is present, `FaceEmbeddingService` returns `nil` for embeddings; onboarding still saves photos, and the camera will not identify anyone until a valid model is added.
