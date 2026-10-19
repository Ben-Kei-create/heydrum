import SwiftUI

struct SectionCard<Content: View>: View {
    var fill: Color = Palette.pureWhite
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Metrics.cardRadius))
    }
}
