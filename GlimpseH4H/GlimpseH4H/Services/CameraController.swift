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
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .back

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

    func switchCamera() {
        let next: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        queue.async { [weak self] in
            self?.reconfigureInput(position: next)
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            addInput(for: currentPosition)
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            }
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.session.startRunning()
            }
        }
    }

    private func reconfigureInput(position: AVCaptureDevice.Position? = nil) {
        let newPosition = position ?? currentPosition
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        addInput(for: newPosition)
        session.commitConfiguration()
        DispatchQueue.main.async { [weak self] in
            self?.currentPosition = newPosition
        }
    }

    private func addInput(for position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        IdentificationPipeline.shared.processFrame(sampleBuffer)
    }
}
