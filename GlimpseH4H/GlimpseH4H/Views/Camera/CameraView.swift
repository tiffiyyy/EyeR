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
        ZStack {
            CameraPreview(
                session: camera.session,
                faceRects: pipeline.visibleFaceOutlines.map(\.boundingBox)
            )
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFullScreen.toggle()
                }
            }

            if let roomName = pipeline.currentRoomName {
                RoomNameBanner(roomName: roomName)
            }
            if let identified = pipeline.currentlyIdentifiedPerson,
               let person = dataStore.people.first(where: { $0.id == identified.personId }) {
                IdentificationCardView(person: person)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            FlipCameraButton(onTap: { camera.switchCamera() })
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

private struct FlipCameraButton: View {
    var onTap: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onTap) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Circle().fill(.black.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 20)
            }
            Spacer()
        }
    }
}
