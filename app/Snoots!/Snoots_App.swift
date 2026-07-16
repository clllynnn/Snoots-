//
//  Snoots_App.swift
//  Snoots!
//
//  Created by lynn on 2026/7/15.
//

import SwiftUI

@main
struct Snoots_App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = SnootsStore()
    @AppStorage("snoots.displayLanguage") private var displayLanguageRawValue = SnootsLanguage.traditionalChinese.rawValue
    @State private var isShowingLaunchScreen = true
    @State private var shouldShowLaunchScreenOnNextActivation = false

    private var displayLanguage: SnootsLanguage {
        SnootsLanguage(rawValue: displayLanguageRawValue) ?? .traditionalChinese
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isShowingLaunchScreen {
                    LaunchScreenView()
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            guard !Task.isCancelled else { return }
                            isShowingLaunchScreen = false
                        }
                } else {
                    ContentView(
                        store: store,
                        language: displayLanguage,
                        displayLanguageRawValue: $displayLanguageRawValue
                    )
                    .environment(\.locale, displayLanguage.locale)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    shouldShowLaunchScreenOnNextActivation = true
                case .active where shouldShowLaunchScreenOnNextActivation:
                    isShowingLaunchScreen = true
                    shouldShowLaunchScreenOnNextActivation = false
                default:
                    break
                }
            }
        }
    }
}

private struct LaunchScreenView: View {
    var body: some View {
        Image("LaunchLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 260, height: 260)
            .accessibilityLabel("Snoots")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SnootsPalette.primary)
            .ignoresSafeArea()
    }
}
