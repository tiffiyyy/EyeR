//
//  CameraController.swift
//  GlimpseH4H
//

import AVFoundation
import UIKit

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.queue")
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Current camera position; used for flip button and face detection orientation.
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    override init() {
        super.init()
    }

    func checkPermissionsAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            break
        }
    }

    /// Switch between front and back camera.
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        configureAndStart()
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            if let current = session.inputs.first { session.removeInput(current) }
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                return
            }
            if session.canAddInput(input) { session.addInput(input) }
            if videoOutput == nil {
                let output = AVCaptureVideoDataOutput()
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: queue)
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    videoOutput = output
                }
            }
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.session.startRunning()
            }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        IdentificationPipeline.shared.processFrame(sampleBuffer, cameraPosition: cameraPosition)
    }
}
