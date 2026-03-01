//
//  AppTheme.swift
//  GlimpseH4H
//

import SwiftUI

enum AppTheme {
    static let navBarBackground = LinearGradient(
        colors: [Color(red: 0.85, green: 0.80, blue: 0.95), Color(red: 0.80, green: 0.85, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardBackground = Color.white
    static let accentPurple = Color(red: 0.55, green: 0.45, blue: 0.75)
    static let faceOutlineColor = Color.white
    static let cardCornerRadius: CGFloat = 16
    static let navIconSize: CGFloat = 24
}
