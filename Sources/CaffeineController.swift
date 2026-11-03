import Foundation
import Observation

/// Owns the `/usr/bin/caffeinate` process that keeps the Mac awake.
@MainActor
@Observable
final class CaffeineController {
    private(set) var isAwake = false
    private(set) var startedAt: Date?
    private(set) var lastError: String?

    var keepDisplayOn: Bool = UserDefaults.standard.object(forKey: Keys.keepDisplayOn) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(keepDisplayOn, forKey: Keys.keepDisplayOn)
            if isAwake { restart() }
        }
    }

    @ObservationIgnored private var process: Process?

    func toggle() {
        isAwake ? stop() : start()
    }

    func start() {
        guard process == nil else { return }
        let caffeinate = Process()
        caffeinate.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        caffeinate.arguments = arguments
        caffeinate.terminationHandler = { [weak self] finished in
            let pid = finished.processIdentifier
            let status = finished.terminationStatus
            Task { @MainActor in self?.processDidExit(pid: pid, status: status) }
        }
        do {
            try caffeinate.run()
            process = caffeinate
            isAwake = true
            startedAt = startedAt ?? .now
            lastError = nil
        } catch {
            lastError = String(localized: "Could not start caffeinate: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let running = process else { return }
        process = nil
        running.terminate()
        isAwake = false
        startedAt = nil
    }

    /// Applies new flags without losing the "awake since" time.
    private func restart() {
        let since = startedAt
        stop()
        startedAt = since
        start()
    }

    private func processDidExit(pid: Int32, status: Int32) {
        // A stop() call clears `process` first, so only unexpected exits reach this branch.
        guard let running = process, running.processIdentifier == pid else { return }
        process = nil
        isAwake = false
        startedAt = nil
        lastError = String(localized: "caffeinate stopped on its own (code \(Int(status))).")
    }

    /// -d display, -i idle sleep, -m disk, -s system sleep (on AC power).
    /// -w ties caffeinate to this app, so it also stops if the app crashes.
    private var arguments: [String] {
        let flags = keepDisplayOn ? "-dims" : "-ims"
        return [flags, "-w", String(ProcessInfo.processInfo.processIdentifier)]
    }

    private enum Keys {
        static let keepDisplayOn = "keepDisplayOn"
    }
}
