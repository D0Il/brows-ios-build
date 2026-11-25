import UIKit

/// Physical confirmation for the few actions a thumb repeats all day.
///
/// Deliberately four call sites, not every control: a browser that buzzes on
/// every tap is a toy, and the desktop rail has no such feedback to be faithful
/// to. What a phone adds is a light tick when a tab is opened, chosen or closed
/// and a selection tick when a page is bookmarked — the moments where the
/// screen's change is otherwise easy to miss under a thumb.
///
/// `prepare()` is called immediately before the event so the Taptic Engine is
/// already awake on the first tap; on the simulator these are no-ops, which is
/// why the UI suite is unaffected.
/// Observable state for the invisible probes. A plain static counter would be
/// read once when the rail first lays out and never redraw, so the tests would
/// read a stale zero however many times the action ran.
final class DebugCounters: ObservableObject {
    static let shared = DebugCounters()
    @Published var haptics = "open 0|pick 0"
    @Published var presses = 0
    private init() {}
}

enum Haptics {
    private static let tap = UIImpactFeedbackGenerator(style: .light)
    private static let pick = UISelectionFeedbackGenerator()

    private(set) static var openedCount = 0
    private(set) static var pickedCount = 0

    /// The Taptic Engine cannot be felt on a simulator, so the observable part of
    /// the promise is that the four named moments actually ask for a haptic. The
    /// UI suite reads this through `debug.haptics` and fails if an action that
    /// should tick does not.
    static var debugCounts: String { "open \(openedCount)|pick \(pickedCount)" }

    static func opened() {
        openedCount += 1
        DebugCounters.shared.haptics = debugCounts
        tap.prepare()
        tap.impactOccurred(intensity: 0.55)
    }

    static func picked() {
        pickedCount += 1
        DebugCounters.shared.haptics = debugCounts
        pick.prepare()
        pick.selectionChanged()
    }
}
