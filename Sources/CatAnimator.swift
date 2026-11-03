import AppKit
import Observation

/// One sprite sheet row. Rows were drawn at different sizes, so each row gets its own scale.
enum SpriteRow {
    case coffee, spin, floor

    var scale: CGFloat {
        switch self {
        case .coffee: 0.62
        case .spin: 0.8
        case .floor: 0.9
        }
    }
}

struct CatFrame: Equatable {
    let image: String
    let row: SpriteRow
    let seconds: Double

    static let sleeping = CatFrame(image: "sleep_body", row: .floor, seconds: 0)

    static func coffee(_ index: Int, _ seconds: Double) -> CatFrame {
        CatFrame(image: "coffee_\(index)", row: .coffee, seconds: seconds)
    }
}

enum SpriteCache {
    @MainActor private static var images: [String: NSImage] = [:]

    @MainActor
    static func image(_ name: String) -> NSImage {
        if let cached = images[name] { return cached }
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "frames")
        let image = url.flatMap(NSImage.init(contentsOf:)) ?? NSImage()
        images[name] = image
        return image
    }
}

/// Plays the cat animations. The view restarts `run(awake:)` each time the state changes.
@MainActor
@Observable
final class CatAnimator {
    private(set) var frame: CatFrame = .sleeping
    @ObservationIgnored private var wantsSpin = false
    /// The last state that `run(awake:)` showed. nil until the first run.
    @ObservationIgnored private var lastAwake: Bool?

    private static let coffeeLoop: [CatFrame] = [
        .coffee(1, 1.4), .coffee(2, 0.9), .coffee(3, 0.35), .coffee(4, 1.2),
        .coffee(3, 0.3), .coffee(5, 1.0), .coffee(1, 0.8), .coffee(6, 1.3),
    ]

    private static let spin: [CatFrame] =
        (1...7).map { CatFrame(image: "spin_\($0)", row: .spin, seconds: 0.14) }
        + [CatFrame(image: "spin_7", row: .spin, seconds: 0.6)]

    private static let wakeUp: [CatFrame] = [
        CatFrame(image: "stretch_1", row: .floor, seconds: 0.6),
        CatFrame(image: "stretch_2", row: .floor, seconds: 0.9),
    ]

    private static let walkToBed: [CatFrame] =
        Array(repeating: (1...4).map { CatFrame(image: "walk_\($0)", row: .floor, seconds: 0.13) }, count: 3)
        .flatMap { $0 }

    func requestSpin() {
        wantsSpin = true
    }

    func run(awake: Bool) async {
        // Play a transition only for a real change, not when a view appears again.
        let changed = lastAwake.map { $0 != awake } ?? false
        lastAwake = awake
        if awake {
            if changed, await !play(Self.wakeUp) { return }
            await loopCoffee()
        } else {
            wantsSpin = false
            if changed, await !play(Self.walkToBed) { return }
            frame = .sleeping
        }
    }

    private func loopCoffee() async {
        while !Task.isCancelled {
            for step in Self.coffeeLoop {
                if wantsSpin {
                    wantsSpin = false
                    guard await play(Self.spin) else { return }
                }
                guard await show(step) else { return }
            }
        }
    }

    /// Returns false when the task was cancelled, so the caller stops.
    private func play(_ frames: [CatFrame]) async -> Bool {
        for step in frames {
            guard await show(step) else { return false }
        }
        return true
    }

    private func show(_ step: CatFrame) async -> Bool {
        frame = step
        do {
            try await Task.sleep(for: .seconds(step.seconds))
            return true
        } catch {
            return false
        }
    }
}
