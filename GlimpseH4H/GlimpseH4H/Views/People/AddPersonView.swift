//
//  AddPersonView.swift
//  GlimpseH4H
//

import SwiftUI

struct AddPersonView: View {
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    var existingPerson: Person?

    @State private var name = ""
    @State private var relationship = ""
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
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
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(.black.opacity(0.6)))
                                    }
                                    .offset(x: 6, y: -6)
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
                    RequiredTextField(label: "Name", text: $name, placeholder: "Name")
                    RequiredTextField(label: "Relationship", text: $relationship, placeholder: "Relationship to you")
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
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                PhotoLibraryPicker(
                    maxSelectionCount: maxPhotos - capturedImages.count,
                    onComplete: { newImages in
                        let space = maxPhotos - capturedImages.count
                        capturedImages.append(contentsOf: newImages.prefix(space))
                        showPhotoLibrary = false
                    },
                    onCancel: { showPhotoLibrary = false }
                )
            }
            .onAppear {
                if let p = existingPerson {
                    name = p.name
                    relationship = p.relationship
                    capturedImages = p.embeddingData.compactMap { UIImage(data: $0) }
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !relationship.trimmingCharacters(in: .whitespaces).isEmpty
            && capturedImages.count >= minPhotos
    }

    private func saveAndDismiss() {
        let data = capturedImages.prefix(maxPhotos).compactMap { $0.jpegData(compressionQuality: 0.8) }
        if let existing = existingPerson {
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespaces)
            updated.relationship = relationship.trimmingCharacters(in: .whitespaces)
            updated.embeddingData = data
            dataStore.updatePerson(updated)
        } else {
            let person = Person(
                name: name.trimmingCharacters(in: .whitespaces),
                relationship: relationship.trimmingCharacters(in: .whitespaces),
                conversationSummary: "",
                embeddingData: data
            )
            dataStore.addPerson(person)
        }
        dismiss()
    }
}
