import SwiftUI

/// Hosts tabs, the full-screen playback overlay and THE shared ad slot (docs/01 §1, §3).
/// Tab screens and the playback screen never own a banner.
struct AppShellView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AdMobManager.self) private var ads
    @Environment(KeyboardObserver.self) private var keyboard

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(spacing: 0) {
        ZStack {
            TabView(selection: $coordinator.selectedTab) {
                NavigationStack(path: $coordinator.homePath) {
                    HomeView()
                        .navigationDestination(for: HomeDestination.self) { destination in
                            switch destination {
                            case .drum: DrumView()
                            case .voiceEditor: VoiceEditorView()
                            }
                        }
                }
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)

                NavigationStack { HistoryView() }
                    .tabItem { Label("履歴", systemImage: "clock") }
                    .tag(AppTab.history)

                NavigationStack { SettingsView() }
                    .tabItem { Label("設定", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .tint(Palette.primaryOrange)
            .accessibilityHidden(coordinator.isPlaybackVisible)

            if coordinator.isPlaybackVisible {
                PlaybackView()
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
                    .zIndex(1)
            }
        }
        if ads.isSlotPresent && !keyboard.isVisible {
            AdSlotView()
        }
        }
        .background(Palette.paper.ignoresSafeArea())
    }
}
