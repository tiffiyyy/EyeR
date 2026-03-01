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
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            if capturedImages.count < maxPhotos {
                                Menu {
                                    Button {
                                        showCamera = true
                                    } label: { Label("Camera", systemImage: "camera.fill") }
                                    PhotosPicker(
                                        selection: $selectedLibraryItems,
                                        maxSelectionCount: maxPhotos - capturedImages.count,
                                        matching: .images
                                    ) {
                                        Label("Photo Library", systemImage: "photo.on.rectangle.angled")
                                    }
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
            }
        }
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
        await MainActor.run { selectedLibraryItems = [] }
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
