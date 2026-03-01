//
//  AddRoomView.swift
//  GlimpseH4H
//

import SwiftUI
import PhotosUI

struct AddRoomView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    var existingRoom: Room?

    @State private var name = ""
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var selectedLibraryItems: [PhotosPickerItem] = []
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
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                }
                Section("Details") {
                    TextField("Room name", text: $name)
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
                    set: { if let img = $0 { capturedImages.append(img); showCamera = false } }
                ), sourceType: .camera, onDismiss: { showCamera = false })
            }
            .onChange(of: selectedLibraryItems) { _, newItems in
                Task {
                    await loadPhotos(from: newItems)
                }
            }
            .onAppear {
                if let r = existingRoom {
                    name = r.name
                    capturedImages = r.imageData.compactMap { UIImage(data: $0) }
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
            && capturedImages.count >= minPhotos
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data), capturedImages.count < maxPhotos {
                await MainActor.run { capturedImages.append(img) }
            }
        }
        await MainActor.run { selectedLibraryItems = [] }
    }

    private func saveAndDismiss() {
        let data = capturedImages.prefix(maxPhotos).compactMap { $0.jpegData(compressionQuality: 0.8) }
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
