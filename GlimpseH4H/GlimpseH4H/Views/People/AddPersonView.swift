//
//  AddPersonView.swift
//  GlimpseH4H
//

import SwiftUI
import PhotosUI

struct AddPersonView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    var existingPerson: Person?

    @State private var name = ""
    @State private var relationship = ""
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var selectedLibraryItems: [PhotosPickerItem] = []
    @State private var saveResultMessage: String?
    @State private var showSaveResultAlert = false
    /// Index → true if a face was detected (will produce an embedding). Updated when photos change.
    @State private var faceDetectedInPhoto: [Int: Bool] = [:]
    private let minPhotos = 4
    private let maxPhotos = 8

    private var isEditing: Bool { existingPerson != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photos (at least \(minPhotos))") {
                    Text("Add photos from camera or your photo library.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, img in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        capturedImages.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .red)
                                    }
                                    .padding(4)
                                    faceBadge(for: index)
                                }
                            }
                            if capturedImages.count < maxPhotos {
                                addPhotoButton(
                                    icon: "camera.fill",
                                    label: "Camera"
                                ) { showCamera = true }
                                PhotosPicker(
                                    selection: $selectedLibraryItems,
                                    maxSelectionCount: maxPhotos - capturedImages.count,
                                    matching: .images
                                ) {
                                    addPhotoButtonLabel(icon: "photo.on.rectangle.angled", label: "Photo Library")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    if capturedImages.count < minPhotos {
                        Text("Add at least \(minPhotos - capturedImages.count) more photo(s).")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("Only the detected face is used for recognition; background is ignored. ✓ = face found.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("Details") {
                    TextField("Name", text: $name)
                    TextField("Relationship to you", text: $relationship)
                }
            }
            .navigationTitle(isEditing ? "Edit Person" : "Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { saveAndDismiss() }
                        .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: Binding(
                    get: { nil },
                    set: { if let img = $0 { capturedImages.append(img); showCamera = false } }
                ), sourceType: .camera, onDismiss: { showCamera = false })
            }
            .onChange(of: selectedLibraryItems) { _, newItems in
                Task {
                    await loadPhotos(from: newItems)
                }
            }
            .onAppear {
                if let p = existingPerson {
                    name = p.name
                    relationship = p.relationship
                    capturedImages = p.embeddingData.compactMap { UIImage(data: $0) }
                }
                checkFacesInPhotos()
            }
            .onChange(of: capturedImages.count) { _, _ in
                checkFacesInPhotos()
            }
            .alert("Saved", isPresented: $showSaveResultAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let msg = saveResultMessage {
                    Text(msg)
                }
            }
        }
    }

    private func addPhotoButtonLabel(icon: String, label: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }

    private func addPhotoButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            addPhotoButtonLabel(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !relationship.trimmingCharacters(in: .whitespaces).isEmpty
            && capturedImages.count >= minPhotos
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data), capturedImages.count < maxPhotos {
                await MainActor.run { capturedImages.append(img) }
            }
        }
        await MainActor.run { selectedLibraryItems = []; checkFacesInPhotos() }
    }

    private func checkFacesInPhotos() {
        let images = capturedImages
        Task.detached(priority: .userInitiated) {
            var result: [Int: Bool] = [:]
            for (index, img) in images.enumerated() {
                result[index] = FaceEmbeddingService.shared.hasDetectableFace(in: img)
            }
            await MainActor.run {
                faceDetectedInPhoto = result
            }
        }
    }

    @ViewBuilder
    private func faceBadge(for index: Int) -> some View {
        Group {
            if let ok = faceDetectedInPhoto[index] {
                Image(systemName: ok ? "face.smiling.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(ok ? .green : .orange)
                    .padding(4)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func saveAndDismiss() {
        let images = Array(capturedImages.prefix(maxPhotos))
        let photoData = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        let embeddings: [[Float]] = images.compactMap {
            FaceEmbeddingService.shared.embedding(from: $0)
        }
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = existingPerson {
            var updated = existing
            updated.name = nameTrimmed
            updated.relationship = relationship.trimmingCharacters(in: .whitespaces)
            updated.embeddingData = photoData
            updated.faceEmbeddings = embeddings
            dataStore.updatePerson(updated)
        } else {
            let person = Person(
                name: nameTrimmed,
                relationship: relationship.trimmingCharacters(in: .whitespaces),
                conversationSummary: "",
                embeddingData: photoData,
                faceEmbeddings: embeddings
            )
            dataStore.addPerson(person)
        }
        if embeddings.isEmpty {
            if FaceEmbeddingService.shared.isModelAvailable {
                saveResultMessage = "Saved, but no face embeddings were created. Make sure each photo clearly shows one face (not too small or far away)."
            } else {
                saveResultMessage = "Saved. Face recognition is unavailable—add FaceEmbedding.mlmodel to the app target for recognition."
            }
        } else {
            let total = images.count
            if embeddings.count < total {
                saveResultMessage = "Saved with \(embeddings.count) face embedding\(embeddings.count == 1 ? "" : "s") from \(total) photos. \(total - embeddings.count) photo(s) had no detectable face—use closer, clearer face shots. \(nameTrimmed) can be recognized by the camera."
            } else {
                saveResultMessage = "Saved with \(embeddings.count) face embedding\(embeddings.count == 1 ? "" : "s"). \(nameTrimmed) can be recognized by the camera."
            }
        }
        showSaveResultAlert = true
    }
}
