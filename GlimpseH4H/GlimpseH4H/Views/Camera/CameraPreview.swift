//
//  CameraPreview.swift
//  GlimpseH4H
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrorWhenBackCamera: Bool = false

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.session = session
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.setMirrored(mirrorWhenBackCamera)
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMirrored(_ mirrored: Bool) {
        previewLayer.connection?.isVideoMirrored = mirrored
    }
}
