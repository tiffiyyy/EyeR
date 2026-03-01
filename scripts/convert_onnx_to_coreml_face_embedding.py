#!/usr/bin/env python3
"""
Convert an ONNX face-embedding model to Core ML (FaceEmbedding.mlmodel).

The output model expects one image input and outputs one embedding vector,
so it can be used with GlimpseH4H's FaceEmbeddingService.

Usage:
  pip install coremltools onnx
  python scripts/convert_onnx_to_coreml_face_embedding.py path/to/model.onnx [output.mlmodel]

Example with Hugging Face FaceNet ONNX:
  1. Download from https://huggingface.co/haikalmumtaz/facenet-onnx (e.g. model.onnx)
  2. python scripts/convert_onnx_to_coreml_face_embedding.py model.onnx
  3. Add the generated FaceEmbedding.mlmodel to the GlimpseH4H Xcode target.
"""

import argparse
import sys
from pathlib import Path

try:
    import onnx
except ImportError:
    print("Install onnx: pip install onnx", file=sys.stderr)
    sys.exit(1)

try:
    import coremltools as ct
except ImportError:
    print("Install coremltools: pip install coremltools", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Convert ONNX face embedding model to Core ML")
    parser.add_argument("onnx_path", type=Path, help="Path to the .onnx model file")
    parser.add_argument(
        "output_path",
        type=Path,
        nargs="?",
        default=None,
        help="Output path for .mlmodel (default: FaceEmbedding.mlmodel in current dir)",
    )
    parser.add_argument(
        "--min-ios",
        type=str,
        default="13",
        help="Minimum iOS deployment target (default: 13)",
    )
    args = parser.parse_args()

    onnx_path = args.onnx_path.resolve()
    if not onnx_path.exists():
        print(f"Error: not found: {onnx_path}", file=sys.stderr)
        sys.exit(1)

    output_path = args.output_path
    if output_path is None:
        output_path = Path("FaceEmbedding.mlmodel")
    output_path = output_path.resolve()
    if output_path.suffix.lower() != ".mlmodel":
        output_path = output_path.with_suffix(".mlmodel")

    # Load ONNX and infer input name and shape
    onnx_model = onnx.load(str(onnx_path))
    graph = onnx_model.graph
    if not graph.input:
        print("Error: ONNX model has no inputs", file=sys.stderr)
        sys.exit(1)

    first_input = graph.input[0]
    input_name = first_input.name
    # Shape may be (batch, channels, height, width) e.g. [1, 3, 160, 160]
    shape = [d.dim_value for d in first_input.type.tensor_type.shape.dim]
    if len(shape) == 4 and shape[1] == 3:
        # NCHW: mark as image so Vision can feed it
        image_input_names = [input_name]
        print(f"Input '{input_name}' shape {shape} -> treating as image (C,H,W)")
    else:
        image_input_names = []
        print(f"Input '{input_name}' shape {shape} -> not treated as image")

    # Convert using the legacy ONNX converter (reliable for image input + embedding output)
    try:
        mlmodel = ct.converters.onnx.convert(
            str(onnx_path),
            image_input_names=image_input_names,
            minimum_ios_deployment_target=args.min_ios,
        )
    except Exception as e:
        print(f"Conversion failed: {e}", file=sys.stderr)
        sys.exit(1)

    mlmodel.save(str(output_path))
    print(f"Saved: {output_path}")
    print("Add this file to the GlimpseH4H Xcode target and ensure it is named FaceEmbedding.mlmodel.")


if __name__ == "__main__":
    main()
