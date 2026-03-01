//
//  AddRoomView.swift
//  GlimpseH4H
//

import SwiftUI

struct AddRoomView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    var existingRoom: Room?

    @State private var name = ""
    @State private var capturedImages: [IdentifiableImage] = []
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    private let minPhotos = 4
    private let maxPhotos = 6

    private var isEditing: Bool { existingRoom != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photos (at least \(minPhotos))") {
                    Text("Add photos from camera or your photo library.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(capturedImages) { item in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        capturedImages.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(.black.opacity(0.5)))
                                    }
                                    .padding(4)
                                }
                            }
                            if capturedImages.count < maxPhotos {
                                Menu {
                                    Button {
                                        showCamera = true
                                    } label: { Label("Camera", systemImage: "camera.fill") }
                                    Button {
                                        showPhotoLibrary = true
                                    } label: { Label("Photo Library", systemImage: "photo.on.rectangle.angled") }
                                } label: {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .frame(width: 80, height: 80)
                                        .overlay {
                                            Image(systemName: "plus.circle")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        }
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
                }
                Section("Details") {
                    TextField("Name (required)", text: $name)
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Name is required.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Room" : "Add Room")
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
                    set: { if let img = $0 { capturedImages.append(IdentifiableImage(image: img)); showCamera = false } }
                ), sourceType: .camera, onDismiss: { showCamera = false })
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoLibraryPicker(
                    isPresented: $showPhotoLibrary,
                    maxSelectionCount: max(1, maxPhotos - capturedImages.count)
                ) { images in
                    for img in images.prefix(maxPhotos - capturedImages.count) {
                        capturedImages.append(IdentifiableImage(image: img))
                    }
                }
            }
            .onAppear {
                if let r = existingRoom {
                    name = r.name
                    capturedImages = r.imageData.compactMap { UIImage(data: $0) }.map { IdentifiableImage(image: $0) }
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && capturedImages.count >= minPhotos
    }

    private func saveAndDismiss() {
        let data = capturedImages.prefix(maxPhotos).compactMap { $0.image.jpegData(compressionQuality: 0.8) }
        if let existing = existingRoom {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.imageData = data
            dataStore.updateRoom(updated)
        } else {
            let room = Room(name: name.trimmingCharacters(in: .whitespaces), imageData: data)
            dataStore.addRoom(room)
        }
        dismiss()
    }
}
