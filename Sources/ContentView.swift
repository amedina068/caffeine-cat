import AppKit
import SwiftUI

/// Colors that follow the system appearance (light or dark).
enum Palette {
    static let background = adaptive(light: 0xF7F1E8, dark: 0x171210)
    static let ink = adaptive(light: 0x2A201B, dark: 0xF2E6D1)
    static let muted = adaptive(light: 0x7D6E62, dark: 0x9E8F80)
    static let glow = adaptive(light: 0xE8945A, dark: 0xD97A3D)
    static let shelf = Color(nsColor: NSColor(hex: 0x73503A))
    static let cream = Color(nsColor: NSColor(hex: 0xF2E6D1))

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// The cat panel. The window uses the full size. The menu bar uses the compact size.
struct CaffeinePanel: View {
    var compact = false
    @Environment(CaffeineController.self) private var caffeine

    var body: some View {
        @Bindable var caffeine = caffeine
        VStack(spacing: compact ? 14 : 20) {
            ZStack(alignment: .bottom) {
                RadialGradient(colors: [Palette.glow.opacity(caffeine.isAwake ? 0.4 : 0.08), .clear],
                               center: .center, startRadius: 10, endRadius: 150 * zoom)
                    .frame(width: 300 * zoom, height: 220 * zoom)
                    .animation(.easeInOut(duration: 1.2), value: caffeine.isAwake)
                CatStage(isAwake: caffeine.isAwake, zoom: zoom)
            }

            VStack(spacing: 6) {
                Text(caffeine.isAwake ? "Your Mac is awake" : "Your Mac can sleep")
                    .font(.system(compact ? .headline : .title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                StatusLine(startedAt: caffeine.startedAt)
            }

            Button(action: caffeine.toggle) {
                Label(caffeine.isAwake ? "Let it sleep" : "Give it coffee",
                      systemImage: caffeine.isAwake ? "moon.zzz.fill" : "cup.and.heat.waves.fill")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 8 : 10)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(caffeine.isAwake ? Palette.cream : Palette.background)
            .background(caffeine.isAwake ? Palette.shelf : Palette.ink, in: .rect(cornerRadius: 10))
            .keyboardShortcut(.defaultAction)

            Toggle(compact ? "Display on" : "Keep the display on", isOn: $caffeine.keepDisplayOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Palette.muted)

            if let error = caffeine.lastError {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
            }

            if compact {
                Divider()
                MenuBarFooter()
            }
        }
        .padding(.horizontal, compact ? 20 : 28)
        .padding(.top, compact ? 18 : 36)
        .padding(.bottom, compact ? 14 : 24)
        .frame(width: compact ? 300 : 340)
        .background(Palette.background)
    }

    private var zoom: CGFloat { compact ? 0.72 : 1 }
}

/// Links at the bottom of the menu bar panel.
private struct MenuBarFooter: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack {
            Button("Open window") {
                NSApp.setActivationPolicy(.regular)
                openWindow(id: "main")
                NSApp.activate()
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.system(.callout, design: .monospaced))
        .foregroundStyle(Palette.muted)
    }
}

/// "Awake for 0:12:30" — updates every second while awake.
private struct StatusLine: View {
    let startedAt: Date?

    var body: some View {
        Group {
            if let startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    Text("Awake for \(elapsed(since: startedAt, now: context.date))")
                }
            } else {
                Text("Give it coffee to keep it awake")
            }
        }
        .font(.system(.callout, design: .monospaced))
        .foregroundStyle(Palette.muted)
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

func elapsed(since start: Date, now: Date = .now) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(start)))
    return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond))
}
