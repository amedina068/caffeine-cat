import SwiftUI

/// The animated cat. Click the cat while it is awake to make it spin.
struct CatStage: View {
    let isAwake: Bool
    var zoom: CGFloat = 1
    @State private var animator = CatAnimator()

    var body: some View {
        ZStack(alignment: .bottom) {
            if animator.frame == .sleeping {
                SleepingCat(zoom: zoom)
            } else {
                sprite(animator.frame.image, row: animator.frame.row, zoom: zoom)
            }
        }
        .frame(width: 260 * zoom, height: 200 * zoom, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { if isAwake { animator.requestSpin() } }
        .task(id: isAwake) { await animator.run(awake: isAwake) }
        .accessibilityElement()
        .accessibilityLabel(isAwake ? "Cat drinking coffee" : "Sleeping cat")
    }
}

/// The sleeping frame: the body breathes and the two Zs float up on their own.
private struct SleepingCat: View {
    let zoom: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                sprite("sleep_body", row: .floor, zoom: zoom)
                    .scaleEffect(x: 1, y: 1 + 0.025 * sin(t * 1.8), anchor: .bottom)
                floatingZ("sleep_z1", t: t, delay: 0)
                floatingZ("sleep_z2", t: t, delay: 1.1)
            }
        }
    }

    private func floatingZ(_ name: String, t: Double, delay: Double) -> some View {
        let phase = ((t + delay).truncatingRemainder(dividingBy: 2.2)) / 2.2
        // The Zs are white in the sprite sheet. A template tint keeps them visible in light mode.
        return sprite(name, row: .floor, zoom: zoom, template: true)
            .foregroundStyle(Palette.muted)
            .offset(x: 4 * phase * zoom, y: -14 * phase * zoom)
            .opacity(phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85)
    }
}

@MainActor
private func sprite(_ name: String, row: SpriteRow, zoom: CGFloat, template: Bool = false) -> some View {
    let image = SpriteCache.image(name)
    let scale = row.scale * zoom
    return Image(nsImage: image)
        .renderingMode(template ? .template : .original)
        .resizable()
        .interpolation(.high)
        .frame(width: image.size.width * scale, height: image.size.height * scale)
}
