//
//  Snoots_App.swift
//  Snoots!
//
//  Created by lynn on 2026/7/15.
//

import SwiftUI

@main
struct Snoots_App: App {
    @State private var store = SnootsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
