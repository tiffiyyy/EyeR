//
//  PhotoLibraryPicker.swift
//  GlimpseH4H
//
//  Presents PHPicker for multi-image selection from the photo library.
//

import SwiftUI
import PhotosUI

private final class SynchronizedArray<Element> {
    private var storage: [Element] = []
    private let lock = NSLock()
    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(element)
    }
}

/// Presents the system photo picker; calls `onImagesPicked` with selected images when done.
/// Present via .sheet(isPresented:) and set isPresented to false when picker dismisses.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var maxSelectionCount: Int
    var onImagesPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = maxSelectionCount
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if results.isEmpty {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
                return
            }
            let group = DispatchGroup()
            let loaded = SynchronizedArray<UIImage>()
            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage {
                        loaded.append(img)
                    }
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.parent.onImagesPicked(loaded.values)
                self.parent.isPresented = false
            }
        }
    }
}
