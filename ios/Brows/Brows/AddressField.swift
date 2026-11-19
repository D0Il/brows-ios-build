import SwiftUI
import UIKit

/// The address pill's editor. SwiftUI's TextField cannot select all on focus and
/// places the caret wherever the tap landed, so a second edit concatenated the new
/// URL onto the old one. UITextField gives us that control: every tap selects the
/// whole current URL, so the next keystroke replaces it.
struct AddressField: UIViewRepresentable {
    @Binding var text: String
    var onSubmit: (String) -> Void
    var onFocus: () -> Void
    var onBlur: () -> Void
    /// CI capture hook: start in the pill's selected (typing) state.
    var autoFocus: Bool = false

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.accessibilityIdentifier = "rail.address"
        field.font = .systemFont(ofSize: 15)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak field] in
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AddressField
        weak var field: UITextField?

        init(_ parent: AddressField) {
            self.parent = parent
        }

        /// Called for every tap, including a tap while the field is already first
        /// responder, because that is the case where the caret used to sit mid-URL.
        @objc func selectAllText() {
            parent.onFocus()
            guard let field else { return }
            if !field.isFirstResponder {
                field.becomeFirstResponder()
            }
            field.selectAll(nil)
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocus()
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
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
