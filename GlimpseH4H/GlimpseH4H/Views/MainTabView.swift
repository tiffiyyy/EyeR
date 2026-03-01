//
//  MainTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .camera
    @State private var cameraFullScreen = false

    enum Tab {
        case camera
        case people
        case rooms
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraTabView(isFullScreen: $cameraFullScreen)
                .tag(Tab.camera)
            PeopleTabView()
                .tag(Tab.people)
            RoomsTabView()
                .tag(Tab.rooms)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            if !cameraFullScreen {
                BottomNavBar(selectedTab: $selectedTab)
            }
        }
        .statusBarHidden(cameraFullScreen)
    }
}

private struct BottomNavBar: View {
    @Binding var selectedTab: MainTabView.Tab

    var body: some View {
        HStack(spacing: 0) {
            navItem(icon: "camera.fill", tab: .camera)
            navItem(icon: "person.2.fill", tab: .people)
            navItem(icon: "book.closed.fill", tab: .rooms)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(AppTheme.cardBackground.opacity(0.95))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private func navItem(icon: String, tab: MainTabView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: icon)
                .font(.system(size: AppTheme.navIconSize))
                .foregroundStyle(selectedTab == tab ? AppTheme.accentPurple : .gray)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
