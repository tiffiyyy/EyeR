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
    private var currentPosition: AVCaptureDevice.Position = .back

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
        currentPosition = currentPosition == .back ? .front : .back
        queue.async { [weak self] in
            self?.reconfigureInput()
        }
    }

    private func configureAndStart() {
        queue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .high
            addInputForCurrentPosition()
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

    private func reconfigureInput() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        addInputForCurrentPosition()
        session.commitConfiguration()
    }

    private func addInputForCurrentPosition() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
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
