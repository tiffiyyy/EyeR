//
//  MainTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .camera
    @State private var cameraFullScreen = false
    @State private var isPaused = false

    enum Tab {
        case camera
        case people
        case rooms
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraTabView(isFullScreen: $cameraFullScreen, isPaused: $isPaused)
                .tag(Tab.camera)
            PeopleTabView()
                .tag(Tab.people)
            RoomsTabView()
                .tag(Tab.rooms)
            SettingsTabView()
                .tag(Tab.settings)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            if !cameraFullScreen {
                BottomNavBar(selectedTab: $selectedTab, isPaused: $isPaused)
            }
        }
        .statusBarHidden(cameraFullScreen)
    }
}

private struct BottomNavBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Binding var isPaused: Bool

    private let navIconSize: CGFloat = 24
    private let pauseButtonSize: CGFloat = 56

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            navItem(icon: "camera.fill", tab: .camera)
            navItem(icon: "person.2.fill", tab: .people)
            pauseResumeButton
            navItem(icon: "book.closed.fill", tab: .rooms)
            navItem(icon: "gearshape.fill", tab: .settings)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var pauseResumeButton: some View {
        Button {
            isPaused.toggle()
        } label: {
            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .frame(width: pauseButtonSize, height: pauseButtonSize)
                .background(Circle().fill(AppTheme.pauseButtonColor))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .offset(y: -18)
    }

    private func navItem(icon: String, tab: MainTabView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: navIconSize))
                .foregroundStyle(selectedTab == tab ? AppTheme.accentPurple : .gray)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
