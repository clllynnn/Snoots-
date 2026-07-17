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
    @AppStorage("snoots.displayLanguage.v2") private var displayLanguageRawValue = SnootsLanguage.systemDefault.rawValue
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
                            try? await Task.sleep(for: .seconds(2.8))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let logoSize: CGFloat = 88

    var body: some View {
        Group {
            if reduceMotion {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
            } else {
                AnimatedGIFView(
                    sourceName: "launch-logo-full-drawing",
                    fallbackImageName: "LaunchLogo"
                )
            }
        }
        .frame(width: logoSize, height: logoSize, alignment: .center)
        .accessibilityLabel("Snoots")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(red: 216 / 255, green: 1, blue: 69 / 255))
        .ignoresSafeArea()
    }
}
