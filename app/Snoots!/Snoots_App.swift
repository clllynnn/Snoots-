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
    @State private var account = SnootsAccountSession()
    @State private var meetups = MeetupRepository()
    @State private var experience = ExperienceRepository()
    @AppStorage("snoots.displayLanguage.v2") private var displayLanguageRawValue = SnootsLanguage.traditionalChinese.rawValue
    @State private var isShowingLaunchScreen = true
    @State private var shouldShowLaunchScreenOnNextActivation = false

    private var displayLanguage: SnootsLanguage {
        .traditionalChinese
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if account.gate == .ready {
                    ContentView(
                        store: store,
                        language: displayLanguage,
                        displayLanguageRawValue: $displayLanguageRawValue
                    )
                } else if account.gate == .needsProfile {
                    OnboardingFlow(store: store, language: displayLanguage, account: account)
                } else if account.gate == .signedOut {
                    AppleLoginView(account: account)
                } else {
                    VStack(spacing: 20) {
                        ProgressView("正在確認登入狀態…")
                        if account.errorMessage != nil {
                            Text(account.errorMessage ?? "")
                                .foregroundStyle(.secondary)
                            Button("重試") { Task { await account.restore() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .environment(\.locale, displayLanguage.locale)
            .environment(account)
            .environment(meetups)
            .environment(experience)
            .preferredColorScheme(.light)
            .onOpenURL { url in
                guard url.scheme == "snoots", url.host == "meetup",
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value,
                      !code.isEmpty else { return }
                meetups.pendingInvitation = code
            }
            .allowsHitTesting(!isShowingLaunchScreen)
            .accessibilityHidden(isShowingLaunchScreen)
            // Keep the app mounted during the launch overlay; individual forms discard unsaved drafts on background.
            .overlay {
                if isShowingLaunchScreen {
                    LaunchScreenView()
                        .task {
                            try? await Task.sleep(for: .seconds(2.8))
                            guard !Task.isCancelled else { return }
                            isShowingLaunchScreen = false
                        }
                }
            }
            .task {
                await account.restore()
                await store.mapPlaces.refreshFromRemoteIfConfigured()
            }
            .onChange(of: account.gate) { _, gate in
                if gate == .ready, let owner = account.owner, let dog = account.dog {
                    store.applyRegisteredProfile(owner: owner, dog: dog, photoData: account.dogPhotoData)
                    if let matchingProfile = account.matchingProfile {
                        store.saveMatchDetails(matchingProfile)
                    }
                } else if gate == .signedOut {
                    store = SnootsStore()
                    meetups.reset()
                    experience.reset()
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
        .background(SnootsPalette.lime)
        .ignoresSafeArea()
    }
}
