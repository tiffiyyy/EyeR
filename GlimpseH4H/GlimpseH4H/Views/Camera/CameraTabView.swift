//
//  CameraTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct CameraTabView: View {
    @Binding var isFullScreen: Bool
    @Binding var isPaused: Bool

    var body: some View {
        CameraView(isFullScreen: $isFullScreen, isPaused: $isPaused)
            .ignoresSafeArea()
    }
}
