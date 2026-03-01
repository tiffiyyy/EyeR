//
//  GlimpseH4HApp.swift
//  GlimpseH4H
//
//  Created by Tiffany Le on 2/28/26.
//

import SwiftUI

@main
struct GlimpseH4HApp: App {
    @StateObject private var dataStore = DataStore.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataStore)
        }
    }
}
