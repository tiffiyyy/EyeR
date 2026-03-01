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
        }
        .background(AppTheme.navBarBackground.opacity(0.3))
    }
}
