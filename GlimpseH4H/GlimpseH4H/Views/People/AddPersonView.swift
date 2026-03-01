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
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
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
                    Button(isEditing ? "Save" : "Add") {
                        Task { await saveAndDismiss() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Generating face embedding...")
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .alert("Could not save person", isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage ?? "Unknown error")
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
                    let source = p.enrollmentImageData.isEmpty ? p.embeddingData : p.enrollmentImageData
                    capturedImages = source.compactMap { UIImage(data: $0) }
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
        await MainActor.run { selectedLibraryItems = [] }
    }

    private func saveAndDismiss() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let enrollment = try FaceEnrollmentService.shared.enroll(from: Array(capturedImages.prefix(maxPhotos)))
            if let existing = existingPerson {
                var updated = existing
                updated.name = name.trimmingCharacters(in: .whitespaces)
                updated.relationship = relationship.trimmingCharacters(in: .whitespaces)
                updated.enrollmentImageData = enrollment.keptImages
                updated.faceEmbedding = enrollment.embedding
                updated.embeddingData = []
                dataStore.updatePerson(updated)
            } else {
                let person = Person(
                    name: name.trimmingCharacters(in: .whitespaces),
                    relationship: relationship.trimmingCharacters(in: .whitespaces),
                    conversationSummary: "",
                    embeddingData: [],
                    enrollmentImageData: enrollment.keptImages,
                    faceEmbedding: enrollment.embedding
                )
                dataStore.addPerson(person)
            }
            dismiss()
        } catch {
            saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
