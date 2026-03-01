//
//  SettingsTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.navBarBackground.opacity(0.3)
                    .ignoresSafeArea()
                List {
                    Section("About") {
                        Label("Glimpse for H4H", systemImage: "eye.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsTabView()
}
