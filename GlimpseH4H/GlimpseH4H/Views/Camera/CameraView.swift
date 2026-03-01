//
//  CameraView.swift
//  GlimpseH4H
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var isFullScreen: Bool
    @StateObject private var camera = CameraController()
    @ObservedObject private var pipeline = IdentificationPipeline.shared
    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFullScreen.toggle()
                        }
                    }

                ForEach(pipeline.visibleFaceOutlines) { outline in
                    FaceOutlineView(rect: outline.boundingBox(in: geo.size))
                }

                if let roomName = pipeline.currentRoomName {
                    RoomNameBanner(roomName: roomName)
                }
                if let identified = pipeline.currentlyIdentifiedPerson,
                   let person = dataStore.people.first(where: { $0.id == identified.personId }) {
                    IdentificationCardView(person: person)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            camera.checkPermissionsAndStart()
            pipeline.start(dataStore: dataStore)
        }
        .onDisappear {
            pipeline.pause()
        }
    }
}

private struct RoomNameBanner: View {
    let roomName: String

    var body: some View {
        Text(roomName)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.cardBackground.opacity(0.95))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct FaceOutlineView: View {
    let rect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(AppTheme.faceOutlineColor, lineWidth: 3)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}
