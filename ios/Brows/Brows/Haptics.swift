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
enum Haptics {
    private static let tap = UIImpactFeedbackGenerator(style: .light)
    private static let pick = UISelectionFeedbackGenerator()

    static func opened() {
        tap.prepare()
        tap.impactOccurred(intensity: 0.55)
    }

    static func picked() {
        pick.prepare()
        pick.selectionChanged()
    }
}
