import SwiftUI
import UIKit

/// The address pill's editor. SwiftUI's TextField cannot replace the whole value on
/// focus and places the caret wherever the tap landed, so a second edit concatenated
/// the new URL onto the old one. UITextField gives us that control: every tap arms
/// the whole current URL for replacement, so the next keystroke replaces it.
///
/// The pill does not hold a visible select-all, unlike a bare selectAll(nil): UIKit
/// draws drag handles above and below the selection, and on a 40 pt pill those
/// handles hang outside the plate, while the end-of-selection scroll hides the host
/// at the left edge. The desktop omnibox puts its caret at the start of the URL on
/// focus; this does the same, keeps the host legible inside the pill, and shows only
/// a caret — the whole value still goes on the first keystroke.
struct AddressField: UIViewRepresentable {
    @Binding var text: String
    var onSubmit: (String) -> Void
    var onFocus: () -> Void
    var onBlur: () -> Void
    /// CI capture hook: start in the pill's selected (typing) state.
    var autoFocus: Bool = false

    func makeUIView(context: Context) -> UITextField {
        let field = FittingTextField()
        field.delegate = context.coordinator
        field.accessibilityIdentifier = "rail.address"
        // The placeholder alone is not a name: VoiceOver read this field as
        // "SEARCH" with no role description of what it edits. The rail's address
        // and search box names itself the way the desktop omnibox is announced.
        field.accessibilityLabel = "Address and search"
        field.font = .systemFont(ofSize: 15)
        // The desktop omnibox keeps the host legible while it is focused: the text
        // stays inside the pill. UIKit scrolls a text field to the *end* of a
        // selection, so a selected long URL showed only its tail and the host
        // vanished (capture pill-dark). Shrink to fit instead, and the whole URL
        // remains visible inside the pill.

        field.textColor = UIColor(Theme.ink)
        field.tintColor = UIColor(Theme.ink)
        field.attributedPlaceholder = NSAttributedString(
            string: "SEARCH",
            attributes: [
                .foregroundColor: UIColor(Theme.panelMuted),
                .font: UIFont.systemFont(ofSize: 15)
            ]
        )
        if autoFocus {
            // The capture hook focuses only after the page it sits over has painted:
            // focusing at launch opened the completions panel against the start
            // page, and its glass kept that wallpaper for the whole capture
            // (pill-dark, run 44896216566).
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak field] in
                field?.becomeFirstResponder()
            }
        }
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.keyboardType = .webSearch
        field.returnKeyType = .go
        field.textContentType = .URL
        field.clearButtonMode = .never
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectAllText))
        tap.cancelsTouchesInView = false
        field.addGestureRecognizer(tap)

        context.coordinator.field = field
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        (field as? FittingTextField)?.refit()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AddressField
        weak var field: UITextField?
        /// The next keystroke replaces the URL, the effect the desktop omnibox gets
        /// from its select-all, without iOS's out-of-pill selection handles.
        private var replacesWholeValue = false

        init(_ parent: AddressField) {
            self.parent = parent
        }

        /// Called for every tap, including a tap while the field is already first
        /// responder, because that is the case where the caret used to sit mid-URL.
        @objc func selectAllText() {
            guard let field else { return }
            // Focus before the model tells anything to snapshot or redraw: a
            // snapshot of a loading page can hold the main runloop for seconds, and
            // the keyboard never came up when that publish happened on this tap
            // (run 44878550611 failed six tests on "rail.address" never taking
            // keyboard focus).
            if !field.isFirstResponder {
                field.becomeFirstResponder()
            }
            parent.onFocus()
            armReplacement(in: field)
        }

        /// Caret at the host, whole value armed for the next keystroke. No
        /// selected range, so UIKit draws a caret and no drag handles. The
        /// field is narrow, so a caret at the head showed only the scheme
        /// ("http:/") and hid the host -- the one part of the URL the pill is
        /// for (captures pill-light/dark, run 45095272714).
        private func armReplacement(in field: UITextField) {
            let text = (field.text ?? "") as NSString
            let scheme = text.range(of: "://")
            let offset = scheme.location == NSNotFound ? 0 : scheme.location + scheme.length
            let start = field.position(from: field.beginningOfDocument, offset: offset)
                ?? field.beginningOfDocument
            field.selectedTextRange = field.textRange(from: start, to: start)
            replacesWholeValue = true
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard replacesWholeValue else { return true }
            replacesWholeValue = false
            // Backspace on an armed field clears it, as a selected-all field would.
            let replacement = string
            textField.text = replacement
            parent.text = replacement
            let end = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: end, to: end)
            return false
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
            (field as? FittingTextField)?.refit()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocus()
            DispatchQueue.main.async {
                self.armReplacement(in: textField)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            replacesWholeValue = false
            parent.onBlur()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            let value = textField.text ?? ""
            textField.resignFirstResponder()
            parent.onSubmit(value)
            return false
        }
    }
}

/// The pill shrinks its URL to fit. UIKit's `adjustsFontSizeToFitWidth` does
/// that only in some states, so the same capture rendered the whole URL at
/// 10 pt in one run and truncated it to `article.h…` in the next (45177700804
/// and 45184392996). The size is computed from the text and the field's own
/// width here, so every pass renders it the same way. 10 pt is the floor;
/// below that the tail is truncated, and the host still leads the URL.
final class FittingTextField: UITextField {
    private let baseFontSize: CGFloat = 15
    private let floorFontSize: CGFloat = 10

    override func layoutSubviews() {
        super.layoutSubviews()
        fitFont()
    }


    /// Re-run the fit after the coordinator has taken a keystroke.
    func refit() { fitFont() }

    private func fitFont() {
        let available = bounds.width - 2
        guard available > 0 else { return }
        let value = text ?? ""
        guard !value.isEmpty else {
            setFontSize(baseFontSize)
            return
        }
        let base = UIFont.systemFont(ofSize: baseFontSize)
        let needed = (value as NSString).size(withAttributes: [.font: base]).width
        let size = needed <= available
            ? baseFontSize
            : max(floorFontSize, baseFontSize * available / needed)
        setFontSize(size)
    }

    private func setFontSize(_ size: CGFloat) {
        if abs((font?.pointSize ?? 0) - size) > 0.05 {
            font = UIFont.systemFont(ofSize: size)
        }
    }
}
