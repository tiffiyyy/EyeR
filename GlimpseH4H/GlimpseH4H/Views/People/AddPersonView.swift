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
    @State private var enrolledFaceCropsResult: EnrolledFaceCropsResult?
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
                    capturedImages = p.photoPaths.compactMap { ImageStore.loadImage(relativePath: $0) }
                }
            }
            .sheet(item: $enrolledFaceCropsResult) { result in
                EnrolledFaceCropsConfirmationView(
                    faceCrops: result.faceCrops,
                    personName: result.personName,
                    onDone: {
                        enrolledFaceCropsResult = nil
                        dismiss()
                    }
                )
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

        let images = Array(capturedImages.prefix(maxPhotos))
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        let relationshipTrimmed = relationship.trimmingCharacters(in: .whitespaces)
        let existing = existingPerson

        Task.detached(priority: .userInitiated) { [dataStore] in
            do {
                let enrollment = try FaceEnrollmentService.shared.enroll(from: images)
                let folder: String
                let personId: UUID
                if let existing = existing {
                    personId = existing.id
                    folder = "person_\(existing.id.uuidString)"
                } else {
                    personId = UUID()
                    folder = "person_\(personId.uuidString)"
                }
                let paths = ImageStore.saveImages(images, under: folder, compressionQuality: 0.8)
                await MainActor.run {
                    if let existing = existing {
                        var updated = existing
                        updated.name = nameTrimmed
                        updated.relationship = relationshipTrimmed
                        updated.photoPaths = paths
                        updated.faceEmbedding = enrollment.embedding
                        dataStore.updatePerson(updated)
                    } else {
                        let person = Person(
                            id: personId,
                            name: nameTrimmed,
                            relationship: relationshipTrimmed,
                            conversationSummary: "",
                            photoPaths: paths,
                            faceEmbedding: enrollment.embedding
                        )
                        dataStore.addPerson(person)
                    }
                    isSaving = false
                    enrolledFaceCropsResult = EnrolledFaceCropsResult(
                        faceCrops: enrollment.faceCrops,
                        personName: nameTrimmed
                    )
                }
            } catch {
                await MainActor.run {
                    saveErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Enrolled faces confirmation

private struct EnrolledFaceCropsResult: Identifiable {
    let id = UUID()
    let faceCrops: [UIImage]
    let personName: String
}

private struct EnrolledFaceCropsConfirmationView: View {
    let faceCrops: [UIImage]
    let personName: String
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("We used these \(faceCrops.count) face\(faceCrops.count == 1 ? "" : "s") for \(personName).")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(faceCrops.enumerated()), id: \.offset) { _, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                }
                Text("These are the faces we'll use for recognition.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
            .padding(.top, 24)
            .navigationTitle("Faces recognized")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
