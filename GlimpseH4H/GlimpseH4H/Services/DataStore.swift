//
//  DataStore.swift
//  GlimpseH4H
//

import Foundation
import UIKit

final class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published private(set) var people: [Person] = []
    @Published private(set) var rooms: [Room] = []

    private let peopleKey = "glimpse_people"
    private let roomsKey = "glimpse_rooms"

    init() {
        load()
    }

    func load() {
        var loaded = (UserDefaults.standard.data(forKey: peopleKey).flatMap { try? JSONDecoder().decode([Person].self, from: $0) }) ?? []
        var didMigrate = false
        for i in loaded.indices where loaded[i].legacyPhotoDataForMigration != nil {
            guard let dataList = loaded[i].legacyPhotoDataForMigration, !dataList.isEmpty else { continue }
            let images = dataList.compactMap { UIImage(data: $0) }
            guard !images.isEmpty else { continue }
            let folder = "person_\(loaded[i].id.uuidString)"
            let paths = ImageStore.saveImages(images, under: folder, compressionQuality: 0.8)
            loaded[i].photoPaths = paths
            loaded[i].legacyPhotoDataForMigration = nil
            didMigrate = true
        }
        people = loaded
        if didMigrate { savePeople() }
        rooms = (UserDefaults.standard.data(forKey: roomsKey).flatMap { try? JSONDecoder().decode([Room].self, from: $0) }) ?? []
    }

    func addPerson(_ person: Person) {
        people.append(person)
        savePeople()
    }

    func updatePerson(_ person: Person) {
        if let i = people.firstIndex(where: { $0.id == person.id }) {
            people[i] = person
            savePeople()
        }
    }

    func removePerson(id: UUID) {
        ImageStore.removeFolder("person_\(id.uuidString)")
        people.removeAll { $0.id == id }
        savePeople()
    }

    func addRoom(_ room: Room) {
        rooms.append(room)
        saveRooms()
    }

    func updateRoom(_ room: Room) {
        if let i = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[i] = room
            saveRooms()
        }
    }

    func removeRoom(id: UUID) {
        rooms.removeAll { $0.id == id }
        saveRooms()
    }

    func updateLastSeen(personId: UUID, at date: Date = Date()) {
        if let i = people.firstIndex(where: { $0.id == personId }) {
            people[i].lastSeenAt = date
            savePeople()
        }
    }

    func appendConversation(personId: UUID, transcript: String, summary: String, startedAt: Date, endedAt: Date) {
        guard let i = people.firstIndex(where: { $0.id == personId }) else { return }
        let record = ConversationRecord(
            personId: personId,
            startedAt: startedAt,
            endedAt: endedAt,
            transcript: transcript,
            summary: summary
        )
        people[i].conversationHistory.append(record)
        people[i].conversationSummary = summary
        savePeople()
    }

    private func savePeople() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        UserDefaults.standard.set(data, forKey: peopleKey)
    }

    private func saveRooms() {
        guard let data = try? JSONEncoder().encode(rooms) else { return }
        UserDefaults.standard.set(data, forKey: roomsKey)
    }
}
