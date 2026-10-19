import SwiftUI
import AVFoundation

@main
struct HeyDrumApp: App {
    @State private var dependencies = AppDependencies.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environment(dependencies.coordinator)
                .environment(dependencies.playback)
                .environment(dependencies.history)
                .environment(dependencies.editor)
                .environment(dependencies.settings)
                .environment(dependencies.preview)
                .environment(dependencies.keyboard)
                .environment(dependencies.ads)
                .environment(\.appDependencies, dependencies)
                .preferredColorScheme(.light)
                .task { await dependencies.startUp() }
                .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { note in
                    let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                    if raw == AVAudioSession.InterruptionType.began.rawValue { dependencies.coordinator.handleInterruption() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                dependencies.coordinator.handleInterruption()
                dependencies.preview.stop()
            case .active:
                Task { await dependencies.purchase.refreshEntitlements() }
            default:
                break
            }
        }
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    @MainActor static let defaultValue: AppDependencies? = nil
}

extension EnvironmentValues {
    var appDependencies: AppDependencies? {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
