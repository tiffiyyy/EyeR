//
//  CameraView.swift
//  GlimpseH4H
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var isFullScreen: Bool
    @Binding var isPaused: Bool
    @StateObject private var camera = CameraController()
    @StateObject private var pipeline = IdentificationPipeline.shared
    @EnvironmentObject private var dataStore: DataStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreview(session: camera.session, mirrorWhenBackCamera: camera.currentPosition == .back)
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

                VStack {
                    HStack {
                        Spacer()
                        CameraFlipButton(camera: camera)
                            .padding(.trailing, 20)
                            .padding(.top, 12)
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            camera.checkPermissionsAndStart()
            if !isPaused {
                pipeline.start(dataStore: dataStore)
            }
        }
        .onDisappear {
            pipeline.pause()
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                pipeline.pause()
            } else {
                pipeline.start(dataStore: dataStore)
            }
        }
    }
}

private struct CameraFlipButton: View {
    @ObservedObject var camera: CameraController

    var body: some View {
        Button {
            camera.switchCamera()
        } label: {
            Image(systemName: "camera.rotate.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .padding(10)
                .background(Circle().fill(.black.opacity(0.4)))
        }
        .buttonStyle(.plain)
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
