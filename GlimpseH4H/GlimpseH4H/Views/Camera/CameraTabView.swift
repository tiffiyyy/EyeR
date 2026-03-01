//
//  CameraTabView.swift
//  GlimpseH4H
//

import SwiftUI

struct CameraTabView: View {
    @Binding var isFullScreen: Bool

    var body: some View {
        CameraView(isFullScreen: $isFullScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all)
    }
}
