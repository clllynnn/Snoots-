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
    @AppStorage("snoots.displayLanguage") private var displayLanguageRawValue = SnootsLanguage.traditionalChinese.rawValue

    private var displayLanguage: SnootsLanguage {
        SnootsLanguage(rawValue: displayLanguageRawValue) ?? .traditionalChinese
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                store: store,
                language: displayLanguage,
                displayLanguageRawValue: $displayLanguageRawValue
            )
            .environment(\.locale, displayLanguage.locale)
        }
    }
}
