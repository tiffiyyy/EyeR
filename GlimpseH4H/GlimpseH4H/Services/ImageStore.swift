//
//  ImageStore.swift
//  GlimpseH4H
//

import Foundation
import UIKit

/// Saves images to Documents so we avoid UserDefaults size limits and persist add/delete correctly.
enum ImageStore {
    private static let base = "glimpse_images"
    private static let fileManager = FileManager.default

    static var rootURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: base)
    }

    /// Saves images under a folder (e.g. person or room id). Returns relative paths. Replaces any existing images in that folder.
    static func saveImages(_ images: [UIImage], under folder: String, compressionQuality: CGFloat = 0.75) -> [String] {
        let dir = rootURL.appending(path: folder)
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        var paths: [String] = []
        for (i, img) in images.prefix(12).enumerated() {
            guard let data = img.jpegData(compressionQuality: compressionQuality) else { continue }
            let name = "\(i).jpg"
            let url = dir.appending(path: name)
            try? data.write(to: url)
            paths.append("\(folder)/\(name)")
        }
        return paths
    }

    static func loadData(relativePath: String) -> Data? {
        let url = rootURL.appending(path: relativePath)
        return try? Data(contentsOf: url)
    }

    static func loadImage(relativePath: String) -> UIImage? {
        loadData(relativePath: relativePath).flatMap { UIImage(data: $0) }
    }

    static func removeFolder(_ folder: String) {
        let url = rootURL.appending(path: folder)
        try? fileManager.removeItem(at: url)
    }
}
