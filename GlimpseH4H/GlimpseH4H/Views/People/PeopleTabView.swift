//
//  PeopleTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct PeopleTabView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var showAddPerson = false
    @State private var personToEdit: Person?
    @State private var personToDelete: Person?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navBarBackground.opacity(0.3)
                    .ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dataStore.people) { person in
                            PersonListCard(
                                person: person,
                                onEdit: { personToEdit = person },
                                onDelete: {
                                    personToDelete = person
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        personToEdit = nil
                        showAddPerson = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accentPurple)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { showAddPerson || personToEdit != nil },
                set: { if !$0 { showAddPerson = false; personToEdit = nil } }
            )) {
                AddPersonView(existingPerson: personToEdit)
                    .onDisappear { showAddPerson = false; personToEdit = nil }
            }
            .alert("Delete contact?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {
                    personToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let p = personToDelete {
                        dataStore.removePerson(id: p.id)
                    }
                    personToDelete = nil
                }
            } message: {
                if let p = personToDelete {
                    Text("Are you sure you want to remove \(p.name)? This cannot be undone.")
                }
            }
        }
    }
}

private struct PersonListCard: View {
    let person: Person
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.headline)
                    Text(person.relationship)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !person.conversationSummary.isEmpty {
                        Text(person.conversationSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let last = person.lastSeenAt {
                        Text("Last seen \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(person.photoPaths.count) photo\(person.photoPaths.count == 1 ? "" : "s"), \(person.faceEmbedding.isEmpty ? "no" : "\(person.faceEmbedding.count)") face embedding")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.accentPurple)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
    }
}

#Preview {
    PeopleTabView()
        .environmentObject(DataStore.shared)
}
