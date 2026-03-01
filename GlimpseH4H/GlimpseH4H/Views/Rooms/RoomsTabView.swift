//
//  RoomsTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct RoomsTabView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var showAddRoom = false
    @State private var roomToEdit: Room?
    @State private var roomToDelete: Room?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navBarBackground.opacity(0.3)
                    .ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dataStore.rooms) { room in
                            RoomListCard(
                                room: room,
                                onEdit: { roomToEdit = room },
                                onDelete: {
                                    roomToDelete = room
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        roomToEdit = nil
                        showAddRoom = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.accentPurple)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { showAddRoom || roomToEdit != nil },
                set: { if !$0 { showAddRoom = false; roomToEdit = nil } }
            )) {
                AddRoomView(existingRoom: roomToEdit)
                    .onDisappear { showAddRoom = false; roomToEdit = nil }
            }
            .alert("Delete room?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {
                    roomToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let r = roomToDelete {
                        dataStore.removeRoom(id: r.id)
                    }
                    roomToDelete = nil
                }
            } message: {
                if let r = roomToDelete {
                    Text("Are you sure you want to remove \"\(r.name)\"? This cannot be undone.")
                }
            }
        }
    }
}

private struct RoomListCard: View {
    let room: Room
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let first = room.imageData.first, let uiImage = UIImage(data: first) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
            Text(room.name)
                .font(.headline)
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
    RoomsTabView()
        .environmentObject(DataStore.shared)
}
