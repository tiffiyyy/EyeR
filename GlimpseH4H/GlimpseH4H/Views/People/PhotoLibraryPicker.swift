//
//  PhotoLibraryPicker.swift
//  GlimpseH4H
//

import SwiftUI
import PhotosUI

/// Presents the system photo library picker and returns selected images. Uses PHPicker so loading works reliably.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var maxSelectionCount: Int
    var onComplete: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelectionCount
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                onCancel()
                return
            }
            loadImages(from: results) { images in
                DispatchQueue.main.async {
                    self.onComplete(images)
                }
            }
        }

        private func loadImages(from results: [PHPickerResult], completion: @escaping ([UIImage]) -> Void) {
            let group = DispatchGroup()
            var images: [UIImage] = []
            let lock = NSLock()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    defer { group.leave() }
                    if let img = obj as? UIImage {
                        lock.lock()
                        images.append(img)
                        lock.unlock()
                    }
                }
            }
            group.notify(queue: .global(qos: .userInitiated)) {
                completion(images)
            }
        }
    }
}
