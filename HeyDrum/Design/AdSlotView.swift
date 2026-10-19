import SwiftUI
import UIKit

/// The ONLY ad slot in the app; owned by AppShell. Never draws fake ads. When there is no ad
/// (loading / no fill / no consent) it keeps its height as a quiet blank area (docs/01 §3).
struct AdSlotView: View {
    @Environment(AdMobManager.self) private var ads
    @State private var width: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        Palette.adBackground
            .frame(height: AdSizing.height(forWidth: width))
            .frame(maxWidth: .infinity)
            .overlay {
                if let banner = ads.banner, ads.status == .visible || ads.status == .loading {
                    BannerContainer(banner: banner).opacity(ads.status == .visible ? 1 : 0)
                }
            }
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { update(geo.size.width) }
                    .onChange(of: geo.size.width) { _, new in update(new) }
            })
            .ignoresSafeArea(.container, edges: .bottom)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("adSlot")
    }

    private func update(_ newWidth: CGFloat) {
        guard newWidth > 0 else { return }
        width = newWidth
        ads.updateSlotWidth(newWidth)
    }
}

private struct BannerContainer: UIViewRepresentable {
    let banner: AdBannerControlling

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if banner.view.superview !== container { attach(to: container) }
    }

    private func attach(to container: UIView) {
        let view = banner.view
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
        ])
    }
}
