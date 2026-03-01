//
//  CameraPreview.swift
//  GlimpseH4H
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// Normalized face rects (0–1) from Vision, origin bottom-left. Drawn in preview layer coordinates.
    var faceRects: [CGRect] = []

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.session = session
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.faceRects = faceRects
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

    var faceRects: [CGRect] = [] {
        didSet {
            faceOverlay.faceRects = faceRects
            faceOverlay.previewLayer = previewLayer
            faceOverlay.setNeedsDisplay()
        }
    }

    private let faceOverlay = FaceOverlayView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        faceOverlay.backgroundColor = .clear
        faceOverlay.isUserInteractionEnabled = false
        addSubview(faceOverlay)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        faceOverlay.frame = bounds
        faceOverlay.setNeedsDisplay()
    }
}

/// Draws face rects in preview layer coordinates. Vision uses normalized (0–1) bottom-left origin;
/// AVCaptureVideoPreviewLayer.rectConverted(fromMetadataOutputRect:) expects top-left origin.
final class FaceOverlayView: UIView {
    var faceRects: [CGRect] = []
    weak var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let layer = previewLayer else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(3)
        for visionNorm in faceRects {
            let topLeftNorm = CGRect(
                x: visionNorm.minX,
                y: 1 - visionNorm.minY - visionNorm.height,
                width: visionNorm.width,
                height: visionNorm.height
            )
            let layerRect = layer.rectConverted(fromMetadataOutputRect: topLeftNorm)
            ctx.stroke(layerRect)
        }
    }
}
