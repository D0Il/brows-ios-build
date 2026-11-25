import Foundation

/// What the address pill did, and what the app was doing at that moment.
///
/// Three runs failed with the pill still reading its placeholder after the test
/// typed a full URL (45400873379, 45408366570, 45520613696), and nothing in the
/// log said whether the tap was swallowed, whether focus arrived, or whether the
/// text was taken and then reset. This records the pill's own events from inside
/// the app, so the next sighting names a mechanism rather than an effect.
///
/// It is inert unless the app is launched with `-BrowsAddressTrace`. Each event is
/// also written to the system log as `BROWS-PILL …`, which the CI job prints, so
/// the evidence survives even when the test never reaches its own print.
final class AddressTrace: ObservableObject {
    static let shared = AddressTrace()
    static var enabled: Bool { CommandLine.arguments.contains("-BrowsAddressTrace") }

    /// The pill's state as the UI tests read it. Only a focus transition or a
    /// changed character count publishes; the event lines themselves never do,
    /// because a mark on every redraw would feed its own re-render.
    @Published private(set) var focus = "focused=0 chars=0 gen=0"

    private let start = ProcessInfo.processInfo.systemUptime
    private var events: [String] = []
    private let lock = NSLock()
    private var watchdog: DispatchSourceTimer?

    func mark(_ event: String) {
        guard Self.enabled else { return }
        let ms = Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
        lock.lock()
        events.append("\(ms) \(event)")
        if events.count > 120 { events.removeFirst(events.count - 120) }
        lock.unlock()
        NSLog("BROWS-PILL %d %@", ms, event)
    }

    var summary: String {
        lock.lock()
        defer { lock.unlock() }
        return events.joined(separator: " | ")
    }

    func setFocus(_ focused: Bool, chars: Int, gen: Int) {
        let next = "focused=\(focused ? 1 : 0) chars=\(chars) gen=\(gen)"
        if focus != next { focus = next }
    }

    /// A main thread that cannot run for a second cannot focus a text field
    /// either. Beat every 250 ms and record how late the main queue ran, so a
    /// swallowed tap caused by a stalled runloop is visible as a number.
    func startWatchdog() {
        guard Self.enabled, watchdog == nil else { return }
        mark("launch")
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 0.25, repeating: 0.25)
        timer.setEventHandler { [weak self] in
            let sent = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async {
                let late = ProcessInfo.processInfo.systemUptime - sent
                if late > 1.0 { self?.mark("STALL \(Int(late * 1000))ms") }
            }
        }
        timer.resume()
        watchdog = timer
    }
}
