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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Section {
                            Text("App settings and preferences.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
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
