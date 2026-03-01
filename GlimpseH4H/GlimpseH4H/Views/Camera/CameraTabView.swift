//
//  CameraTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct CameraTabView: View {
    @Binding var isFullScreen: Bool

    var body: some View {
        ZStack {
            CameraView(isFullScreen: $isFullScreen)
            if !isFullScreen {
                VStack {
                    HStack {
                        Text("Camera")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    Spacer()
                }
            }
        }
        .background(AppTheme.navBarBackground.opacity(0.3))
    }
}
